#
# This source file is part of the EdgeDB open source project.
#
# Copyright 2016-present MagicStack Inc. and the EdgeDB authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


@cython.final
cdef class NamedTupleCodec(BaseNamedRecordCodec):

    cdef decode(self, FRBuffer *buf):
        cdef:
            object result
            Py_ssize_t elem_count
            Py_ssize_t i
            int32_t elem_len
            BaseCodec elem_codec
            FRBuffer elem_buf

        elem_count = <Py_ssize_t><uint32_t>hton.unpack_int32(frb_read(buf, 4))

        if elem_count != len(self.fields_codecs):
            raise RuntimeError(
                f'cannot decode NamedTuple: expected {len(self.fields_codecs)} '
                f'elements, got {elem_count}')

        result = datatypes.namedtuple_new(self.descriptor)

        for i in range(elem_count):
            frb_read(buf, 4)  # reserved
            elem_len = hton.unpack_int32(frb_read(buf, 4))

            if elem_len == -1:
                elem = None
            else:
                elem_codec = <BaseCodec>self.fields_codecs[i]
                elem = elem_codec.decode(
                    frb_slice_from(&elem_buf, buf, elem_len))
                if frb_get_len(&elem_buf):
                    raise RuntimeError(
                        f'unexpected trailing data in buffer after named '
                        f'tuple element decoding: {frb_get_len(&elem_buf)}')

            datatypes.namedtuple_set(result, i, elem)

        return result

    cdef encode_kwargs(self, WriteBuffer buf, dict obj):
        cdef:
            WriteBuffer elem_data
            Py_ssize_t objlen
            Py_ssize_t i
            BaseCodec sub_codec

        self._check_encoder()

        objlen = len(obj)
        if objlen != len(self.fields_codecs):
            raise RuntimeError(
                f'expected {len(self.fields_codecs)} keyword arguments, '
                f'got {objlen}')

        elem_data = WriteBuffer.new()
        for i in range(objlen):
            name = datatypes.record_desc_pointer_name(self.descriptor, i)
            arg = obj[name]

            if arg is None:
                elem_data.write_int32(-1)
            else:
                sub_codec = <BaseCodec>(self.fields_codecs[i])
                try:
                    sub_codec.encode(elem_data, arg)
                except TypeError as e:
                    raise ValueError(
                        f'cannot encode {name!r} argument') from None

        buf.write_int32(4 + elem_data.len())  # buffer length
        buf.write_int32(<int32_t><uint32_t>objlen)
        buf.write_buffer(elem_data)

    @staticmethod
    cdef BaseCodec new(bytes tid, tuple fields_names, tuple fields_codecs):
        cdef:
            NamedTupleCodec codec

        codec = NamedTupleCodec.__new__(NamedTupleCodec)

        codec.tid = tid
        codec.name = 'NamedTuple'
        codec.descriptor = datatypes.record_desc_new(
            fields_names, <object>NULL)
        codec.fields_codecs = fields_codecs

        return codec
