CC     := /usr/local/cuda/bin/nvcc
CFLAGS :=
ALL    := gpugenv

all : $(ALL)

% : %.cu
	$(CC) $(CFLAGS) -o $@ $<

clean:
	rm -f $(ALL)
