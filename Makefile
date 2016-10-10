CFLAGS=$(CCONFIG)
LFLAGS=$(LCONFIG) -lstdc++

ex1:	ex1.cu
		nvcc  $(CFLAGS) -o ex1 ex1.cu $(LFLAGS)

clean:
		rm -f ex1 *.o
