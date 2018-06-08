!*****************************************************************************************
!> author: Jacob Williams
!
!  JSON-Fortran interface for Python.
!
!  Can be used to pass arbitrary data between Fortran and Python by
!  using JSON strings as an intermediate format.

    module python_json_interface_module

    use json_module
    use iso_c_binding

    implicit none

    private

    type,public :: container
        !! a container that holds a variable-length string.
        !! We need this so we can point to it with a pointer.
        character(len=:),allocatable :: str
    end type container

    interface
        function strlen(str) result(isize) bind(C, name='strlen')
            !! C string length
            import
            implicit none
            type(c_ptr),value :: str
            integer(c_int)    :: isize
        end function strlen
    end interface

    public :: json_to_c_ptr

    contains
!*****************************************************************************************

!*****************************************************************************************
!>
!  Returns the length of the string.
!  This should be called from Python to preallocate a string buffer
!  before calling [[populate_character_string]].

    function get_string_length(cp) result(ilen) bind (c, name='get_string_length')
    !DEC$ ATTRIBUTES DLLEXPORT :: get_string_length

    implicit none

    type(c_ptr),intent(in) :: cp    !! pointer to a container
    integer(c_int)         :: ilen  !! the length of the string

    type(container),pointer :: c

    ilen = 0
    if (c_associated(cp)) then
        call c_f_pointer (cp, c)
        if (allocated(c%str)) ilen = len(c%str)
    end if

    end function get_string_length
!*****************************************************************************************

!*****************************************************************************************
!>
!  Populate the `string` with the data from the container.

    subroutine populate_character_string(cp,string) bind(c,name='populate_character_string')
    !DEC$ ATTRIBUTES DLLEXPORT :: populate_character_string

    implicit none

    type(c_ptr),intent(in) :: cp         !! pointer to a container
    type(c_ptr),intent(inout) :: string  !! a preallocated string buffer that 
                                         !! the string will copied into

    type(container),pointer :: c

    if (c_associated(cp)) then
        call c_f_pointer (cp, c)
        if (allocated(c%str)) then
            call f_string_to_c_ptr(c%str, string)
        end if
    end if

    end subroutine populate_character_string
!*****************************************************************************************

!*****************************************************************************************
!>
!  Destroys the string

    subroutine destroy_string(cp) bind (c, name='destroy_string')
    !DEC$ ATTRIBUTES DLLEXPORT :: destroy_string

    implicit none

    type(c_ptr),intent(inout) :: cp  !! pointer to a container

    type(container),pointer :: c

    if (c_associated(cp)) then
        call c_f_pointer (cp, c)
        if (allocated(c%str)) deallocate(c%str)
        deallocate(c)
    end if

    cp = c_null_ptr

    end subroutine destroy_string
!*****************************************************************************************

!*****************************************************************************************
!>
!  convert the c string to a fortran string, and then
!  parse it as json. returns a json_file object

    subroutine c_ptr_to_json(cp,json)

    implicit none
  
    type(c_ptr),intent(in)        :: cp   !! a `c_char_p` from python containing a JSON string.
    type(json_file),intent(inout) :: json !! the JSON data structure

    character(len=:),allocatable :: fstr !! string containing the JSON data

    if (c_associated(cp)) then
        fstr = c_ptr_to_f_string(cp)
        call json%load_from_string(fstr)
        deallocate(fstr)
    end if

    end subroutine c_ptr_to_json
!*****************************************************************************************

!*****************************************************************************************
!>
!  Convert the c string to a pointer to a container holding the string.

    subroutine c_ptr_to_container_c_ptr(cp,ccp) bind (c, name='c_ptr_to_container_c_ptr')
    !DEC$ ATTRIBUTES DLLEXPORT :: c_ptr_to_container_c_ptr

    implicit none

    type(c_ptr),intent(in)  :: cp   !! a `c_char_p` from python 
    type(c_ptr),intent(out) :: ccp  !! pointer to a container that contains the string

    character(len=:),allocatable :: str !! fortran version of the string
    type(container),pointer :: c        !! container to hold the string

    if (c_associated(cp)) then

        ! get the fortran string:
        str = c_ptr_to_f_string(cp)

        ! return a pointer to the container:
        allocate(c)
        c%str = str
        ccp = c_loc(c)

    else
        ccp = c_null_ptr
    end if 

    end subroutine c_ptr_to_container_c_ptr
!*****************************************************************************************

!*****************************************************************************************
!>
!  Convert a `c_ptr` to a string into a Fortran string.

    function c_ptr_to_f_string(cp) result(fstr)

    implicit none

    type(c_ptr),intent(in) :: cp         !! a `c_char_p` from python 
    character(len=:),allocatable :: fstr !! the corresponding fortran string

    integer :: ilen  !! string length

    ilen = strlen(cp)

    block
        !convert the C string to a Fortran string
        character(kind=c_char,len=ilen+1),pointer :: s
        call c_f_pointer(cp,s)
        fstr = s(1:ilen)
        nullify(s)
    end block

    end function c_ptr_to_f_string
!*****************************************************************************************

!*****************************************************************************************
!>
!  Convert a JSON file to a `c_ptr` that can be passed back to Python.

    subroutine json_to_c_ptr(json,cp,destroy)

    implicit none

    type(json_file),intent(inout) :: json  !! JSON data
    type(c_ptr) :: cp !! a pointer to a container 
                      !! containing the JSON data as a string
    logical,intent(in) :: destroy  !! to also destroy the JSON file
                                   !! (must be destroyed on the fortran
                                   !! side somewhere to prevent memory leak)

    character(len=:),allocatable :: str  !! JSON string of the data
    type(container),pointer :: c      !! container to hold the string

    call json%print_to_string(str)
    if (destroy) call json%destroy()

    ! send back a pointer to the container:
    allocate(c)
    c%str = str
    cp = c_loc(c)

    end subroutine json_to_c_ptr
!*****************************************************************************************

!*****************************************************************************************
!>
!  Convert a Fortran string to a `c_ptr`.
!  (the C string must already have been allocated to a fixed size in Python)
!
!@note There is some protection here to make sure the buffer is long enough
!      to hold the string (if [[get_string_length]] was used to allocate it then
!      it should be). If it isn't, then only as much as it can hold is copied.

    subroutine f_string_to_c_ptr(fstr,buffer)

    implicit none

    character(len=*),intent(in) :: fstr  !! a normal fortran string
    type(c_ptr) :: buffer                !! a preallocated string buffer that 
                                         !! the string will copied into

    integer :: ilen !! string length of buffer

    ilen = strlen(buffer) 

    block
        character(kind=c_char,len=ilen+1),pointer :: s
        call c_f_pointer(buffer,s)
        s(1:min(len(fstr),ilen)) = fstr(1:min(len(fstr),ilen))
        buffer = c_loc(s)
    end block

    end subroutine f_string_to_c_ptr
!*****************************************************************************************

! Two test routines:

!*****************************************************************************************
!>
!  Test routine. Call from Python to send JSON data to Fortran.

    subroutine test_send_json_to_fortran(cp) bind (c, name='test_send_json_to_fortran')
    !DEC$ ATTRIBUTES DLLEXPORT :: test_send_json_to_fortran

    implicit none

    type(c_ptr),intent(in) :: cp  !! a `c_char_p` from python containing a JSON string.

    type(json_file) :: json

    integer :: ival

    !call json%initialize()
    ! this causes the print to fail when compiled with ifort.
    ! gfortran works fine.  bug???
    ! call json%initialize(no_whitespace=.true.)   

    call c_ptr_to_json(cp,json)

    ! do something with the data:
    call json%print_file()
    call json%get('1',ival)
    write(*,*) '1: ', ival

    call json%destroy()  ! free memory (note: should add a finalizer to this type... TODO)

    end subroutine test_send_json_to_fortran
!*****************************************************************************************

!*****************************************************************************************
!>
!  Test routine. Call from Python to send JSON data to Fortran.
!  A variable is added to the JSON structure and returned.
!
!  This is an example of an `inout` usage for a JSON variable.

    subroutine test_send_json_to_fortran_container(cp) bind (c, name='test_send_json_to_fortran_container')
    !DEC$ ATTRIBUTES DLLEXPORT :: test_send_json_to_fortran

    implicit none

    type(c_ptr),intent(inout) :: cp  !! a pointer to a container

    type(json_file) :: json
    type(container),pointer :: c

    if (c_associated(cp)) then
        call c_f_pointer (cp, c)
        if (allocated(c%str)) then

            ! parse JSON:
            call json%load_from_string(c%str)

            !do something with the data:
            call json%print_file()
            call json%add('Added in Fortran', [9,10])

            ! convert it to a c_ptr (and destroy JSON structure)
            call json_to_c_ptr(json,cp,destroy=.true.)

        end if
    end if

    end subroutine test_send_json_to_fortran_container
!*****************************************************************************************

!*****************************************************************************************
!>
!  Test routine. Call from Python to get some sample JSON data.

    subroutine test_send_json_to_python(cp) bind (c, name='test_send_json_to_python')
    !DEC$ ATTRIBUTES DLLEXPORT :: test_send_json_to_python
    implicit none

    type(c_ptr) :: cp  !! pointer to a container containing a json string

    type(json_file) :: json

    ! sample data:
    call json%add('Generated in Fortran', .true.)
    call json%add('scalar', 1)
    call json%add('vector', [1,2,3])
    call json%add('string', 'hello')
    call json%add('string array', ['1','2','3'])

    ! convert it to a c_ptr (and destroy JSON structure)
    call json_to_c_ptr(json,cp,destroy=.true.)

    end subroutine test_send_json_to_python
!*****************************************************************************************

!*****************************************************************************************
    end module python_json_interface_module
!*****************************************************************************************