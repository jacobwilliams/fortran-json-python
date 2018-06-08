### Description

Interfacing Fortran and Python via JSON

### Building

* A [FoBiS](https://github.com/szaghi/FoBiS) configuration file (`python_json_interface.fobis`) is also provided that can also build the shared library. Use the `mode` flag to indicate what to build. For example:

  * To build the shared library using gfortran: `FoBiS.py build -f python_json_interface.fobis -mode shared-gnu`
  * To build the shared library using ifort: `FoBiS.py build -f python_json_interface.fobis -mode shared-intel`

  The full set of modes are: `static-gnu`, `static-gnu-debug`, `static-intel`, `static-intel-debug`, `shared-gnu`, `shared-gnu-debug`, `shared-intel`, `shared-intel-debug`, `tests-gnu`, `tests-gnu-debug`, `tests-intel`, `tests-intel-debug`

  To generate the documentation using [ford](https://github.com/cmacmackin/ford), run:

```
  FoBis.py rule --execute makedoc -f python_json_interface.fobis
```
