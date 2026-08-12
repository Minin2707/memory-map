package memory_map.backend.media.image.jvm;

final class JpegExifOrientation {

    static final int DEFAULT_ORIENTATION = 1;

    private static final int SOI = 0xFFD8;
    private static final int APP1 = 0xFFE1;
    private static final int ORIENTATION_TAG = 0x0112;
    private static final int SHORT_TYPE = 3;

    private JpegExifOrientation() {
    }

    static int read(byte[] jpeg) {
        if (jpeg.length < 4 || unsignedShort(jpeg, 0, false) != SOI) {
            return DEFAULT_ORIENTATION;
        }

        int offset = 2;
        while (offset + 4 <= jpeg.length) {
            if ((jpeg[offset] & 0xFF) != 0xFF) {
                return DEFAULT_ORIENTATION;
            }

            int marker = unsignedShort(jpeg, offset, false);
            int length = unsignedShort(jpeg, offset + 2, false);
            int segmentStart = offset + 4;
            int segmentEnd = segmentStart + length - 2;

            if (length < 2 || segmentEnd > jpeg.length) {
                return DEFAULT_ORIENTATION;
            }

            if (marker == APP1 && isExifSegment(jpeg, segmentStart)) {
                return readTiffOrientation(jpeg, segmentStart + 6, segmentEnd);
            }

            offset = segmentEnd;
        }

        return DEFAULT_ORIENTATION;
    }

    private static boolean isExifSegment(byte[] jpeg, int offset) {
        return offset + 6 <= jpeg.length
                && jpeg[offset] == 'E'
                && jpeg[offset + 1] == 'x'
                && jpeg[offset + 2] == 'i'
                && jpeg[offset + 3] == 'f'
                && jpeg[offset + 4] == 0
                && jpeg[offset + 5] == 0;
    }

    private static int readTiffOrientation(
            byte[] data,
            int tiffOffset,
            int segmentEnd
    ) {
        if (tiffOffset + 8 > segmentEnd) {
            return DEFAULT_ORIENTATION;
        }

        boolean littleEndian;
        if (data[tiffOffset] == 'I' && data[tiffOffset + 1] == 'I') {
            littleEndian = true;
        } else if (data[tiffOffset] == 'M' && data[tiffOffset + 1] == 'M') {
            littleEndian = false;
        } else {
            return DEFAULT_ORIENTATION;
        }

        int magic = unsignedShort(data, tiffOffset + 2, littleEndian);
        if (magic != 42) {
            return DEFAULT_ORIENTATION;
        }

        long ifdOffset = unsignedInt(data, tiffOffset + 4, littleEndian);
        int ifd = tiffOffset + (int) ifdOffset;
        if (ifd < tiffOffset || ifd + 2 > segmentEnd) {
            return DEFAULT_ORIENTATION;
        }

        int entries = unsignedShort(data, ifd, littleEndian);
        int entryOffset = ifd + 2;
        for (int index = 0; index < entries; index++) {
            if (entryOffset + 12 > segmentEnd) {
                return DEFAULT_ORIENTATION;
            }

            int tag = unsignedShort(data, entryOffset, littleEndian);
            int type = unsignedShort(data, entryOffset + 2, littleEndian);
            long count = unsignedInt(data, entryOffset + 4, littleEndian);

            if (tag == ORIENTATION_TAG && type == SHORT_TYPE && count == 1) {
                int valueOffset = entryOffset + 8;
                int orientation = unsignedShort(
                        data,
                        valueOffset,
                        littleEndian
                );
                return orientation >= 1 && orientation <= 8
                        ? orientation
                        : DEFAULT_ORIENTATION;
            }

            entryOffset += 12;
        }

        return DEFAULT_ORIENTATION;
    }

    private static int unsignedShort(
            byte[] data,
            int offset,
            boolean littleEndian
    ) {
        if (littleEndian) {
            return (data[offset] & 0xFF)
                    | ((data[offset + 1] & 0xFF) << 8);
        }

        return ((data[offset] & 0xFF) << 8)
                | (data[offset + 1] & 0xFF);
    }

    private static long unsignedInt(
            byte[] data,
            int offset,
            boolean littleEndian
    ) {
        if (littleEndian) {
            return ((long) data[offset] & 0xFF)
                    | (((long) data[offset + 1] & 0xFF) << 8)
                    | (((long) data[offset + 2] & 0xFF) << 16)
                    | (((long) data[offset + 3] & 0xFF) << 24);
        }

        return (((long) data[offset] & 0xFF) << 24)
                | (((long) data[offset + 1] & 0xFF) << 16)
                | (((long) data[offset + 2] & 0xFF) << 8)
                | ((long) data[offset + 3] & 0xFF);
    }
}
