#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char *argv[]){
    if(argc < 2) {

		printf("Usage: %s <input filename> <output filename>", argv[0]);
		exit(0);
    }
    FILE *original, *out_file;
    unsigned int ChunkSize, Subchunk1Size, Subchunk2Size, RIFFSize, fmtSize, dataSize, SampleRate, ByteRate;
    unsigned short int AudioFormat, NumChannels, BlockAlign, BitsPerSample;
    char ChunkID[5], Format[5], Subchunk1ID[5], Subchunk2ID[5];
    ChunkID[4] = '\0';
    Format[4] = '\0';
    Subchunk1ID[4] = '\0';
    Subchunk2ID[4] = '\0';
    char* path, out;
    	
   
   
    original = fopen(argv[1], "rb");
    if (!original) {
        printf("Error: file does not exist.\n");
        return EXIT_FAILURE;
    }
    fread(ChunkID, 4, 1, original);
    fread(&ChunkSize, 4, 1, original);
    fread(Format, 4, 1, original);
    fread(Subchunk1ID, 4, 1, original);
    fread(&Subchunk1Size, 4, 1, original);
    fread(&AudioFormat, 2, 1, original);
    fread(&NumChannels, 2, 1, original);
    fread(&SampleRate, 4, 1, original);
    fread(&ByteRate, 4, 1, original);
    fread(&BlockAlign, 2, 1, original);
    fread(&BitsPerSample, 2, 1, original);
    fread(Subchunk2ID, 4, 1, original);
    fread(&Subchunk2Size, 4, 1, original);
    fmtSize = Subchunk1Size + 8;
    dataSize = Subchunk2Size + 8;
    RIFFSize = ChunkSize + 8 - (fmtSize + dataSize);
    printf("RIFF Size:     %d\n", RIFFSize);
    printf("fmt Size:      %d\n", fmtSize);
    printf("data Size:     %d\n\n", dataSize);
    printf("ChunkID:       %s\n", ChunkID);
    printf("ChunkSize:     %d\n", ChunkSize);
    printf("Format:        %s\n\n", Format);
    printf("Subchunk1ID:   %s\n", Subchunk1ID);
    printf("Subchunk1Size: %d\n", Subchunk1Size);
    printf("AudioFormat:   %d\n", AudioFormat);
    printf("NumChannels:   %d\n", NumChannels);
    printf("SampleRate:    %d\n", SampleRate);
    printf("ByteRate:      %d\n", ByteRate);
    printf("BlockAlign:    %d\n", BlockAlign);
    printf("BitsPerSample: %d\n\n", BitsPerSample);
    printf("Subchunk2ID:   %s\n", Subchunk2ID);
    printf("Subchunk2Size: %d\n", Subchunk2Size);
    out_file = fopen(argv[2], "wb");
    char buf[1024];
    int count;
    while ((count = fread(buf, 1, sizeof(buf), original)) > 0)
   	 fwrite(buf, 1, count, out_file);
	
    fclose(out_file);
     
    fclose(original);
    return EXIT_SUCCESS;
}
