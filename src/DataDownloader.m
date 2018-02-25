#import "DataDownloader.h"

static OFString *downloadFile = @"cube_2005_08_29_unix.tar.gz";
static OFString *downloadURL =
    @"http://tenet.dl.sourceforge.net/project/cube/cube/2005_08_29/"
    @"cube_2005_08_29_unix.tar.gz";
static const uint8_t downloadHash[] = {
	0xF3, 0xBA, 0x21, 0xDD, 0xBA, 0x46, 0x49, 0x29, 0x96, 0xF7, 0xE1, 0x2D,
	0x0B, 0x5A, 0x51, 0xF9, 0x99, 0x89, 0x52, 0x5C, 0xFF, 0x17, 0x83, 0xB1,
	0x6A, 0x23, 0x90, 0xD5, 0x84, 0x97, 0x52, 0xD4, 0xDF, 0x1B, 0x78, 0xD6,
	0x9A, 0x63, 0x46, 0x36, 0xBC, 0x28, 0xE6, 0x8E, 0x4C, 0xDE, 0x33, 0x1C
};

@implementation DataDownloader
- (bool)download
{
	OFFileManager *fileManager = [OFFileManager defaultManager];

	@autoreleasepool {
		of_log(@"Downloading data files...");

		OFHTTPClient *client = [OFHTTPClient client];
		OFHTTPRequest *request = [OFHTTPRequest
		    requestWithURL: [OFURL URLWithString: downloadURL]];
		OFHTTPResponse *response = [client performRequest: request];

		@try {
			response = [client performRequest: request];
		} @catch (id e) {
			of_log(@"Exception while downloading: %@", e);
			goto error;
		}

		OFFile *file = [OFFile fileWithPath: downloadFile
					       mode: @"w"];
		OFSHA384Hash *hash = [OFSHA384Hash cryptoHash];

		int cnt = 0;
		size_t bytes = 0;
		while (![response isAtEndOfStream]) {
			char buffer[1024];
			size_t length = 0;

			length = [response readIntoBuffer: buffer
						   length: 1024];
			bytes += length;

			if ((++cnt % 1000) == 0)
				of_log(@"Got %zd bytes...", bytes);

			[hash updateWithBuffer: buffer
					length: length];
			[file writeBuffer: buffer
				   length: length];
		}

		[file close];

		if (memcmp([hash digest], downloadHash,
		    [[hash class] digestSize]) != 0) {
			of_log(@"Hash mismatch! Aborting...");
			goto error;
		}

		of_log(@"Hash ok, extracting...");

		file = [OFFile fileWithPath: downloadFile
				       mode: @"r"];

		OFGZIPStream *GZIPStream = [OFGZIPStream
		    streamWithStream: file
				mode: @"r"];
		OFTarArchive *archive = [OFTarArchive
		    archiveWithStream: GZIPStream
				 mode: @"r"];
		OFTarArchiveEntry *entry;

		while ((entry = [archive nextEntry]) != nil) {
			if (![entry.fileName hasPrefix: @"cube/data/"] &&
			    ![entry.fileName hasPrefix: @"cube/packages/"])
				continue;

			OFString *name = [entry.fileName substringWithRange:
			    of_range(5, entry.fileName.length - 5)];

			of_log(@"Extracting %@...", name);

			if (entry.type == OF_TAR_ARCHIVE_ENTRY_TYPE_DIRECTORY)
				[fileManager createDirectoryAtPath: name
						     createParents: true];
			else if (entry.type == OF_TAR_ARCHIVE_ENTRY_TYPE_FILE) {
				OFStream *input =
				    [archive streamForReadingCurrentEntry];
				OFFile *output = [OFFile fileWithPath: name
								 mode: @"w"];

				while (!input.atEndOfStream) {
					char buffer[1024];
					size_t length = [input
					    readIntoBuffer: buffer
						    length: 1024];

					[output writeBuffer: buffer
						     length: length];
				}

				[output close];
			} else {
				of_log(@"Unknown type %d! Aborting...",
				    entry.type);
				goto error;
			}
		}
	}

	[fileManager removeItemAtPath: downloadFile];

	return true;

error:
	[fileManager removeItemAtPath: @"data"];
	[fileManager removeItemAtPath: @"packages"];
	[fileManager removeItemAtPath: downloadFile];

	return false;
}
@end
