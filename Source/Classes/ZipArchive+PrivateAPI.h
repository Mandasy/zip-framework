#define ZIP_DISK_TRAILER	(0x06054b50)
#define ZIP_BUFF_SIZE	512

// force structs to minimal size to be able to read from file
#pragma pack(1)

// TODO: read these structs field by field, not as a whole, so
//		 we can remove the pragma pack

/* central directory end record */
typedef struct cde_record {
	uint32_t signature;
	uint16_t curr_disk;
	uint16_t cd_disk;
	uint16_t nr_files_disk;
	uint16_t nr_files;
	uint32_t cd_len;
	uint32_t cd_offset;
	uint16_t comment_len;
} CDERecord;

/* Central directory file header */
typedef struct cd_file_record {
	uint32_t signature; /* 0x02014b50 */
	uint16_t made_by;
	uint16_t min_version;
	uint16_t flag;
	uint16_t compression;
	uint16_t last_mod_time;
	uint16_t last_mod_date;
	uint32_t crc;
	uint32_t compressed; // compressed size
	uint32_t uncompressed; // uncrompressed size
	uint16_t name_len;
	uint16_t extra_len;
	uint16_t comment_len;
	uint16_t disk_start;
	uint16_t int_attr;
	uint32_t ext_attr;
	uint32_t local_offset;
	
	/* file name (variable size) */
	/* extra field (variable size) */
	/* file comment (variable size) */
} CDFileHeader;

#pragma pack()

typedef struct {
	ZipArchive *archive;
	NSString *name;
	int pos;
} ZipEntryIO;

/* Utility functions for reading bytes from little-endian based file */
uint16_t JKReadUInt16(FILE *fp);
uint32_t JKReadUInt32(FILE *fp);

/* BOOL function to check if char pointer points to start of DiskTrailer */
BOOL isDiskTrailer(char *start);

/* Find the location of the disk trailer in the file fp by reading from end to start */
int zipDiskTrailerInFile(FILE *fp, int size);

/* Read a file header from the central directory */
void readCDFileHeader(CDFileHeader *header, FILE *fp);

/**
 * Delegate functions for the virtual zip file stream. Functions call methods on 
 * a ZipArchive object pointed to by the cookie. The cookie is of type ZipEntryIO.
 */
int ZipArchive_entry_do_read(void *cookie, char *buf, int len);


@interface ZipArchive (PrivateAPI)
/**
 * Read all entries from the zip central directory
 */
- (void) readEntries;

/**
 * Delegate method for the virtual zip file stream. Reads the specified number
 * of bytes form the requested file in the ZipArchive.
 */
- (int) readFromEntry:(NSString *)name buffer:(char *)buf length:(int)length;
@end




