from ctypes import *
import json

dll = CDLL ('lib/json.so')

############################################################################################

# define the interfaces to the DLL routines:

# test routines:
test_send_json_to_python = dll.test_send_json_to_python
test_send_json_to_python.argtypes = [POINTER(c_void_p)]   # for container
test_send_json_to_python.restype = None

test_send_json_to_fortran = dll.test_send_json_to_fortran
test_send_json_to_fortran.argtypes = [POINTER(c_char_p)]  
test_send_json_to_fortran.restype = None

test_send_json_to_fortran_container = dll.test_send_json_to_fortran_container
test_send_json_to_fortran_container.argtypes = [POINTER(c_void_p)]   # for container
test_send_json_to_fortran_container.restype = None

get_string_length = dll.get_string_length
get_string_length.argtypes = [POINTER(c_void_p)]    # for container 
get_string_length.restype = c_int

c_ptr_to_container_c_ptr = dll.c_ptr_to_container_c_ptr
c_ptr_to_container_c_ptr.argtypes = [POINTER(c_char_p),POINTER(c_void_p)] 
c_ptr_to_container_c_ptr.restype = None

populate_character_string = dll.populate_character_string
populate_character_string.argtypes = [POINTER(c_void_p),POINTER(c_char_p)]
populate_character_string.restype = None

destroy_string = dll.destroy_string
destroy_string.argtypes = [POINTER(c_void_p)]
destroy_string.restype = None

##################################################################
def python_dict_to_fortran(d):
    """ convert a python dict to a json string 
        that can be passed to fortran as a `c_ptr`
    """

    return python_str_to_fortran(json.dumps(d))

    #...or could combine in one:
    #return cast(create_string_buffer(json.dumps(d).encode()),c_char_p) 

##################################################################
def python_str_to_fortran(s):
    """ convert a normal python string to the format 
        that can be passed to fortran as a `c_ptr`
    """

    return cast(create_string_buffer(s.encode()),c_char_p) 

##################################################################
def python_dict_to_container(d):
    """ convert a python dict to a pointer 
        to a container (that contains the JSON string) 
    """

    return python_str_to_container(json.dumps(d))

##################################################################
def python_str_to_container(s):
    """ convert a normal python string to a pointer 
        to a container (that contains the string) 
    """

    cp = python_str_to_fortran(s) # a c_char_p

    # convert to pointer to a container:
    ccp = c_void_p() 
    c_ptr_to_container_c_ptr(byref(cp),byref(ccp)) 

    return ccp

##################################################################
def fortran_str_to_python_dict(cp,destroy=True):
    """ convert a pointer to a container to a python dict.
        the string is expected to contain a valid JSON structure.
    """

    return json.loads(fortran_to_python_string(cp,destroy=destroy))

##################################################################
def fortran_to_python_string(cp,destroy=True):
    """ convert a pointer to a container to a python string.
        Optionally, destroy it on the fortran side
        (it needs to be destroyed somehow in order
        to prevent memory leaks since I don't think 
        Python will do it)
    """

    # get the length of the string:
    length = c_int()
    length = get_string_length(byref(cp))

    # preallocate a string buffer of the correct size to hold it:
    s = c_char_p()
    s = cast(create_string_buffer(b' '.ljust(length)),c_char_p)

    # now convert it to a normal python string:
    populate_character_string(byref(cp),byref(s))
    string = s.value.decode()

    if (destroy):
        # now destroy it on the Fortran side:
        destroy_string(byref(cp))

    return string

##################################################################
if __name__ == '__main__': 

    """ example use cases """

    # generate an example structure:
    a = {'Generated in Python': True,
         'scalar': 1, 
         'vector': [1,2,3], 
         'string': 'hello'}

    print('')
    print('-----------------------')
    print('print dict in python...')
    print('')
    print(str(a))

    print('')
    print('-----------------------')
    print('convert to and from a container type...')
    print('')

    print('')
    c = python_dict_to_container(a)
    d = fortran_str_to_python_dict(c,destroy=True)
    print(d)
    print('')

    print('')
    print('-----------------------')
    print('from python to fortran (c_char_p)...')
    print('')

    # convert dict to json string and send it to fortran:
    cp = python_dict_to_fortran(a)
    test_send_json_to_fortran(byref(cp))

    print('')
    print('-----------------------')
    print('from python to fortran (container)...')
    print('')

    cp = python_dict_to_container(a)                 # to a container pointer
    test_send_json_to_fortran_container(byref(cp))   # send to Fortran, where it is modified
    d = fortran_str_to_python_dict(cp,destroy=True)  # convert back to dict (and destroy the Fortran variable)
    print('')
    print('modified by Fortran:')
    #print(d)
    print(json.dumps(d, indent=2))


    print('')
    print('-----------------------')
    print('from fortran to python...')
    print('')

    # now, retrieve a dict string from fortran:
    cp = c_void_p() 
    test_send_json_to_python(byref(cp))

    # convert it to a normal python dict 
    # (destroying the fortran variable in the process to prevent a memory leak)
    d = fortran_str_to_python_dict(cp,destroy=True)

    print(json.dumps(d, indent=2))
    print('')
    if ('Generated in Fortran' in d):
        print('Generated in Fortran: ' + str(d['Generated in Fortran']))

    print('')



