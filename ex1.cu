/* C stuff */
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>

// C++ stuff
#include <iostream>
#include <fstream>
#include <string>
#include <iomanip>
#include <sstream>

// Open-CV for the vision stuff
//#include <opencv2/opencv.hpp>

/* Cuda stuff */
#include <cuda_runtime_api.h>
#include <cuda.h>

typedef unsigned char byte;
typedef byte * pbyte;

clock_t LastProfilingClock=clock();

#define ARCH_NEWLINE	"\n"

/***************************************************************************
 Writes profiling output (milli-seconds since last call)
 ***************************************************************************/

extern clock_t LastProfilingClock;

inline float profiling (const char *s, clock_t *whichClock=NULL) 
{
	if (whichClock==NULL)
		whichClock=&LastProfilingClock;

    clock_t newClock=clock();
    float res = (float) (newClock-*whichClock) / (float) CLOCKS_PER_SEC;
    if (s!=NULL)
        std::cerr << "Time: " << s << ": " << res << std::endl; 
    *whichClock = newClock;
    return res;
}

inline float profilingTime (const char *s, time_t *whichClock) 
{
    time_t newTime=time(NULL);
    float res = (float) (newTime-*whichClock);
    if (s!=NULL)
        std::cerr << "Time(real): " << s << ": " << res << std::endl; 
    return res;
}

/***************************************************************************
 CREATES AN EMPTY IMAGE
 ***************************************************************************/

unsigned char **CREATE_IMAGE (int ysize, int xsize)	{
	unsigned char ** im;
	unsigned char *big;

	im = new pbyte [xsize];
	big	= new byte [xsize*ysize];

	for	(int i = 0 ; i < xsize ; i++)
		im[i] =	big	+ i*ysize;	

	return (im);
}

/***************************************************************************
 Frees an image
 ***************************************************************************/

void FREE_IMAGE	(byte **im)	
{
	delete [] im[0];
	delete [] im;
}

/***************************************************************************
 Reads a grayscale image
 ***************************************************************************/

void readImage (const char *filename, unsigned char***_p2darr, int *_ysize, int *_xsize) {

	char *buf;
	char shortbuf[256];
	short int x, y;
	int	color, foo;
	char c;
	FILE * inpic;
	int	entete,	z;
	int ysize, xsize;
	unsigned char **R;

	if ( (inpic	= fopen(filename,"r+b")) == NULL)	
	{
		std::cerr << "can't open file '" << filename << "': " << strerror(errno) << std::endl;
		exit(1);
	}

	if (fscanf(inpic,"%c%c\n",&c,&c) !=	2) 
	{
		std::cerr <<  "Image::readGray():\n Wrong Image Format: no .ppm!!\n"
  			 << "filename: " << filename << std::endl;
  		exit(2);
	}

	if (c == '6')  
	{
		z =	3 ;
		std::cerr << "Image::readGray():: disabled due to bug.\n"
			"Use Image::readColor() + Image::convertRGB2GrayScale() instead\n";
		exit(3);
	}
	else
	{
		if (c != '5') {
			std::cerr <<  "Image::readGray():: wrong image format: "
				"for .ppm only versions P5 and P6 are supported!\n";
			exit(4);
		}
		z =	1 ;
	}

	fscanf(inpic,"%c",&c) ;
	entete = 3 ;
	while (c ==	'#') {
		entete++ ;
		while (c !=	'\n') {
			entete++ ;
			fscanf(inpic,"%c",&c) ;
		}
		fscanf(inpic,"%c",&c) ;
	}

	if ( (inpic	= freopen(filename,"r+b",inpic)) == NULL)	{
		std::cerr << "can't open file " << filename << ":" << strerror(errno) << "\n";
		exit(5);
	}
	fread(shortbuf,1,entete,inpic);

	if (fscanf(inpic,"%d%d\n%d",&xsize,&ysize,&color) != 3)	{
		std::cerr << "Internal error (2):" << filename << std::endl;
		exit(6);
	}

	fread(shortbuf,1,1,inpic) ;

	buf	= new char [z*xsize+10];

	R =	CREATE_IMAGE(ysize,xsize) ;
	for	( y	= 0	; y	< ysize	; y++) 
	{

		if ((foo=fread(buf,1,z*xsize,inpic)) != z*xsize) 
		{
			std::ostringstream s;
			s << "file " << filename << ":\nrow " << y << " input failure: "
				<< "got " << foo << " instead of " << z*xsize << " bytes!\n";
			
			if (!feof(inpic))
				s << "No ";			
			s << "EOF occured.\n";
			if (!ferror(inpic))
				s << "No ";			
			std::cerr << "error in the sense of ferror() occured.\n";
			exit(7);
		}
		else 
		{
			if (z == 1)	
			{
				for	( x	= 0	; x	< xsize	; x++)
					R[x][y]	= buf[x] ;
			}
			else 
			{
				for	( x	= 0	; x	< z*xsize ;	x += z )
					R[x/z][y] =	(int)(.299*(float)buf[x] + 0.587*(float)buf[x+1]
						+ 0.114*(float)buf[x+2]);
			}
		}
	}
	fclose (inpic);
	delete [] buf;

	*_ysize = ysize;
	*_xsize = xsize;
	*_p2darr = R;
}

// *************************************************************
// Writes a	grayscale image
// *************************************************************

void writeImage(const char *filename, unsigned char **R, int ysize, int xsize) 
{
	FILE *fp;
	char *buf;
	short int y, x;

    if ((fp=fopen(filename,"w+b"))==NULL) 
    {
    	std::cerr << "Cannot create output file '" << filename << "': " << strerror(errno) << "!\n";
    	exit(1);
    }
    		
	buf = new char [xsize+10];

	sprintf(buf,"P5%s%d	%d%s255%s",ARCH_NEWLINE,xsize,ysize,ARCH_NEWLINE,ARCH_NEWLINE)	;
	x =	strlen(buf);
	clearerr(fp);
	fwrite(buf,1,x,fp);
	if (ferror(fp)) 
	{
		std::cerr << "Could not write image to file (Image::writeGray())!\n";
		exit(1);
	}

	for	( y	= 0	; y	< ysize	; y++)	{
		for	( x	= 0	; x	< xsize	; x++ )	{
			buf[x] = R[x][y];
		}

		clearerr(fp);
		fwrite(buf,1,xsize,fp);
		if (ferror(fp))
		{
			std::cerr << "Could not write image to file (Image::writeGray())!\n";
			exit(1);
		}
	}
	delete [] buf;
	fclose(fp);
}

/***************************************************************************
 USAGE
 ***************************************************************************/

void usage (char *com) 
{
    std::cerr<< "usage: " << com << " <inputimagename> <outputimagename>\n";
    exit(1);
}

/***************************************************************************
 The CPU version
 ***************************************************************************/

void cpuFilter(unsigned char *in, unsigned char *out, int rows, int cols)
{

	// General case
	for (int y=1; y<rows-1; ++y)
	for (int x=1; x<cols-1; ++x)
	{
		float f = (
			4.0*in[x*rows+y] +
			2.0*in[(x-1)*rows+y] +
			2.0*in[(x+2)*rows+y] +
			2.0*in[x*rows+y+1] +
			2.0*in[x*rows+y-1] +
			in[(x-1)*rows+y-1] +
			in[(x-1)*rows+y+1] +
			in[(x+1)*rows+y-1] +
			in[(x+1)*rows+y+1]
			)/16.0;
		if (f<0) f=0;
		if (f>255) f=255;
		out[x*rows+y] = (unsigned char) f;
	}
	
	// Borders
	for (int y=0; y<rows; ++y)
	{
		out[0*rows+y] = in[0*rows+y];
		out[(cols-1)*rows+y] = in[(cols-1)*rows+y];
	}
		
	for (int x=0; x<cols; ++x)
	{
		out[x*rows+0] = in[x*rows+0];
		out[x*rows+rows-1] = in[x*rows+rows-1];
	}
}

/***************************************************************************
 The GPU version - the kernel
 ***************************************************************************/

__global__
void gpuHostRun(int mxWidth, unsigned char* input, unsigned char* output)
{
	int x = blockIdx.x*blockDim.x + threadIdx.x; // cols
	int y = blockIdx.y*blockDim.y + threadIdx.y; // rows
	if(y*mxWidth + x <= mxWidth*mxWidth)
	{
		if(!(y == mxWidth-1 || y == 0 || x == mxWidth-1 || x == 0)){	
		
			float f = (
				4.0*input[x*mxWidth+y] +
				2.0*input[(x-1)*mxWidth+y] +
				2.0*input[(x+2)*mxWidth+y] +
				2.0*input[x*mxWidth+y+1] +
				2.0*input[x*mxWidth+y-1] +
				input[(x-1)*mxWidth+y-1] +
				input[(x-1)*mxWidth+y+1] +
				input[(x+1)*mxWidth+y-1] +
				input[(x+1)*mxWidth+y+1]
				)/16.0;
			if (f<0) f=0;
			if (f>255) f=255;
			output[x*mxWidth+y] = (unsigned char) f;
		}
		else {
			output[x*mxWidth+y] = input[x*mxWidth+y];		
		}
	}
}


 /***************************************************************************
 The GPU version - the host code
 ***************************************************************************/

void gpuFilter(unsigned char *imarr, unsigned char *resarr, int rows, int cols ) // dimY == nbRows, dimX == nbCol
{
	unsigned char *gpuMatrix1; //input
	unsigned char *gpuMatrix2; //output
	

	int matrixInByte = rows*cols*sizeof(char);
	
	cudaMalloc((void**) &gpuMatrix1, matrixInByte);
	cudaMalloc((void**) &gpuMatrix2, matrixInByte);

	cudaError_t ok = cudaMemcpy(gpuMatrix1, imarr, matrixInByte, cudaMemcpyHostToDevice );
	if(ok != cudaSuccess)
	{
		std::cerr <<"*** Could not transfer\n";
		exit(1);
	}

	dim3 dimBlock(32,32);
	dim3 dimGrid(cols/dimBlock.x,rows/dimBlock.y);

	gpuHostRun<<<dimGrid, dimBlock>>>(cols, gpuMatrix1, gpuMatrix2);

	cudaMemcpy(resarr, gpuMatrix2, matrixInByte, cudaMemcpyDeviceToHost );
	if(ok != cudaSuccess)
	{
		std::cerr <<"*** Could not transfer\n";
		exit(1);
	}
	
}

	
/***************************************************************************
 Main program
 ***************************************************************************/


int main (int argc, char **argv)
{
	int c;
	// Argument processing
    while ((c =	getopt (argc, argv,	"h")) != EOF) 
    {
		switch (c) {

			case 'h':
				usage(*argv);
				break;
	
			case '?':
				usage (*argv);
				std::cerr << "\n" << "*** Problem parsing the options!\n\n";
				exit (1);
		}
	}	

    int requiredArgs=2;

	if (argc-optind!=requiredArgs) 
    {
        usage (*argv);
		exit (1);
	}
	char *inputfname=argv[optind];
	char *outputfname=argv[optind+1];

	std::cout << "Reading image " << inputfname << "\n";

	unsigned char **image;
	int rows; 
	int cols;
	readImage (inputfname, &image, &rows, &cols);
	
	std::cout << "=====================================================\n"
		<< "Loaded image of size " << cols << "x" << rows << ".\n";

	unsigned char *imarr = *image;
	unsigned char *resarr = new unsigned char [cols*rows];

	profiling (NULL);
	
	for (int i=0; i<100; ++i)
		cpuFilter(imarr, resarr, rows, cols);

	profiling ("CPU version");

	for (int i=0; i<100; ++i)
		gpuFilter(imarr, resarr, rows, cols);
	
	profiling ("GPU version");

	// Copy flat array back to image structure
	for (int i=0; i<rows*cols; ++i)
		imarr[i] = resarr[i];
	
	writeImage (outputfname, image, rows, cols);
	
    std::cout << "Program terminated correctly.\n";
    return 0;
}

