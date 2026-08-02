# Linux (Debian)

## Build DUST

```bash
sudo apt install gcc g++ gfortran
```

```bash
sudo apt install cmake liblapack-dev libblas-dev libopenblas-dev libopenblas0 libcgns-dev libhdf5-dev
```

```bash
mkdir build && cd build
```

```bash
cmake -DCMAKE_BUILD_TYPE=$CMAKE_BUILD_TYPE -DWITH_PRECICE=$WITH_PRECICE ../
```

where:

- **$CMAKE_BUILD_TYPE** can be **Release** or **Debug**
- **$WITH_PRECICE** can be **YES** or **NO**

  For example:

  ```bash
  cmake -DCMAKE_BUILD_TYPE=Release -DWITH_PRECICE=NO ../
  ```

```bash
make
```

Tip: You can use aliases in order to reference the executables.

```bash
alias dust='~/dust/build/bin/dust'
alias dust_post='~/dust/build/bin/dust_post'
alias dust_pre='~/dust/build/bin/dust_pre'
alias ddd='dust_pre && dust && dust_post'
```

- **Run DUST**

Inside the configuration folder run:

```bash
dust_pre
dust
dust_post
```

or

```bash
ddd
```
