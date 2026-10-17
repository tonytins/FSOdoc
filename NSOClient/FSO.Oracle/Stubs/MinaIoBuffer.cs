// Stands in for Mina.NET's IoBuffer, which FreeSO took from a fork that isn't checked
// out here. It implements the members FreeSO's SimAntics and FSO.Common sources call,
// with Mina's semantics: a position, a limit, an optional auto-expanding capacity, and
// big-endian order by default.
using System;
using System.Text;

namespace Mina.Core.Buffer
{
    public enum ByteOrder
    {
        BigEndian,
        LittleEndian,
    }

    public class IoBuffer
    {
        private byte[] _bytes;
        private int _position;
        private int _limit;
        private int _mark = -1;

        private IoBuffer(byte[] bytes, int position, int limit)
        {
            _bytes = bytes;
            _position = position;
            _limit = limit;
        }

        public static IoBuffer Allocate(int capacity) => new IoBuffer(new byte[capacity], 0, capacity);

        public static IoBuffer Wrap(byte[] bytes) => new IoBuffer(bytes, 0, bytes.Length);

        public static IoBuffer Wrap(byte[] bytes, int offset, int length) => new IoBuffer(bytes, offset, offset + length);

        public ByteOrder Order { get; set; } = ByteOrder.BigEndian;
        public bool AutoExpand { get; set; }
        public int Capacity => _bytes.Length;
        public int Remaining => _limit - _position;
        public bool HasRemaining => _position < _limit;

        public int Position
        {
            get => _position;
            set
            {
                if (value < 0 || value > _limit) throw new ArgumentOutOfRangeException(nameof(value));
                _position = value;
            }
        }

        public int Limit
        {
            get => _limit;
            set
            {
                if (value < 0 || value > _bytes.Length) throw new ArgumentOutOfRangeException(nameof(value));
                _limit = value;
                if (_position > value) _position = value;
            }
        }

        public IoBuffer Flip()
        {
            _limit = _position;
            _position = 0;
            _mark = -1;
            return this;
        }

        public IoBuffer Mark()
        {
            _mark = _position;
            return this;
        }

        public IoBuffer Reset()
        {
            if (_mark < 0) throw new InvalidOperationException("no mark");
            _position = _mark;
            return this;
        }

        public IoBuffer Skip(int count)
        {
            Ensure(count, writing: false);
            _position += count;
            return this;
        }

        // Single bytes and byte arrays.

        public byte Get()
        {
            Ensure(1, writing: false);
            return _bytes[_position++];
        }

        public IoBuffer Get(byte[] destination, int offset, int length)
        {
            Ensure(length, writing: false);
            Array.Copy(_bytes, _position, destination, offset, length);
            _position += length;
            return this;
        }

        public IoBuffer Put(byte value)
        {
            Ensure(1, writing: true);
            _bytes[_position++] = value;
            return this;
        }

        public IoBuffer Put(IoBuffer source)
        {
            var count = source.Remaining;
            var bytes = new byte[count];
            source.Get(bytes, 0, count);
            return Put(bytes);
        }

        public IoBuffer Put(byte[] source)
        {
            Ensure(source.Length, writing: true);
            Array.Copy(source, 0, _bytes, _position, source.Length);
            _position += source.Length;
            return this;
        }

        // Integers, in the buffer's byte order.

        public short GetInt16() => (short)ReadUnsigned(2);
        public ushort GetUInt16() => (ushort)ReadUnsigned(2);
        public int GetInt32() => (int)ReadUnsigned(4);
        public uint GetUInt32() => (uint)ReadUnsigned(4);
        public long GetInt64() => (long)ReadUnsigned(8);
        public ulong GetUInt64() => ReadUnsigned(8);

        public IoBuffer PutInt16(short value) => WriteUnsigned((ushort)value, 2);
        public IoBuffer PutUInt16(ushort value) => WriteUnsigned(value, 2);
        public IoBuffer PutInt32(int value) => WriteUnsigned((uint)value, 4);
        public IoBuffer PutUInt32(uint value) => WriteUnsigned(value, 4);
        public IoBuffer PutInt64(long value) => WriteUnsigned((ulong)value, 8);
        public IoBuffer PutUInt64(ulong value) => WriteUnsigned(value, 8);

        // Strings.

        public string GetString(int length, Encoding encoding)
        {
            var bytes = new byte[length];
            Get(bytes, 0, length);
            return encoding.GetString(bytes);
        }

        public IoBuffer PutString(string value, Encoding encoding) => Put(encoding.GetBytes(value));

        // Private.

        private ulong ReadUnsigned(int count)
        {
            Ensure(count, writing: false);
            ulong value = 0;
            for (var index = 0; index < count; index++)
            {
                ulong current = _bytes[_position + index];
                value = Order == ByteOrder.BigEndian
                    ? (value << 8) | current
                    : value | (current << (8 * index));
            }
            _position += count;
            return value;
        }

        private IoBuffer WriteUnsigned(ulong value, int count)
        {
            Ensure(count, writing: true);
            for (var index = 0; index < count; index++)
            {
                var shift = Order == ByteOrder.BigEndian ? 8 * (count - 1 - index) : 8 * index;
                _bytes[_position + index] = (byte)(value >> shift);
            }
            _position += count;
            return this;
        }

        private void Ensure(int count, bool writing)
        {
            if (count < 0) throw new ArgumentOutOfRangeException(nameof(count));
            if (_position + count <= _limit) return;
            if (!writing || !AutoExpand) throw new IndexOutOfRangeException("IoBuffer overflow");
            var capacity = Math.Max(_position + count, _bytes.Length * 2);
            Array.Resize(ref _bytes, capacity);
            _limit = capacity;
        }
    }
}
