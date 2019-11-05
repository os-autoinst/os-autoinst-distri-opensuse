# -*- coding: utf-8 -*-
import sys, unittest, types
import six, tap

''' 
Six provides simple utilities for wrapping over differences between Python 2 and Python 3. It is intended to support
codebases that work on both Python 2 and 3 without modification.

Six wraps over differences in roughly 5 categorys:
'''
#category1 python2 and python3's versions and constants.
class test_constants(unittest.TestCase):
    def test_version(self):
        '''python version'''
        if sys.version_info.major == 2:
            self.assertTrue(six.PY2)
        elif sys.version_info.major == 3:
            self.assertTrue(six.PY3)

    def test_maxsize(self):
        '''the maxsize of iterator'''
        self.assertEqual(six.MAXSIZE, sys.maxsize)

#category2 pythons' fundamental types.

class test_types(unittest.TestCase):
    def test_integer_types(self):
        '''integer type'''
        #integer types. In Python 2, this is long and int, and in Python 3, just int.
        self.assertIsInstance(1, six.integer_types)
        self.assertIsInstance(-1, six.integer_types)
        self.assertIsInstance(six.MAXSIZE + 23, six.integer_types)
        self.assertNotIsInstance(.1, six.integer_types)

    # Type for representing binary data. This is str in Python 2 and bytes in Python 3.
    def test_binary_type(self):
        '''binary type'''
        self.assertIs(type(six.b("hi")), six.binary_type)

    # Type for representing (Unicode) textual data. This is unicode() in Python 2 and str in Python 3.
    def test_text_type(self):
        '''text type'''
        self.assertIs(type(six.u("hi")), six.text_type)

    # types for text data. This is basestring() in Python 2 and str in Python 3.
    def test_string_types(self):
        '''string types'''
        self.assertIsInstance("hi", six.string_types)
        self.assertIsInstance(six.u("hi"), six.string_types)
        self.assertTrue(issubclass(six.text_type, six.string_types))

    def test_class_types(self):
        '''class types'''
        class X:
            pass
        class Y(object):
            pass
        self.assertIsInstance(X, six.class_types)
        self.assertIsInstance(Y, six.class_types)
        self.assertNotIsInstance(X(), six.class_types)

#category3 Object model compatibility
class test_object_model(unittest.TestCase):
    '''
    1, Unbound (class) method objects: no self
     Accessing a function attribute of a class by qualifying the class returns an unbound method object.
    2, Bound (instance) method objects:
     Accessing a function attribute of a class by qualifying an instance returns a bound method object.
    '''

    #test the function get_unbound_function,it returns class' unbound function.
    def test_get_unbound_function(self):
        '''get_unbound_function'''
        class X(object):
            def m(self):
                pass
        self.assertIs(six.get_unbound_function(X.m), X.__dict__["m"])

    #test the function get_method_function,it returns instance's method.
    def test_get_method_function(self):
        '''get_method_function'''
        class X(object):
            def m(self):
                pass
        x = X()
        self.assertIs(six.get_method_function(x.m), X.__dict__["m"])

    #test_get_method_self returns instance, i.e. self.
    def test_get_method_self(self):
        '''get_method_self'''
        class X(object):
            def m(self):
                pass
        x = X()
        self.assertIs(six.get_method_self(x.m), x)


    def foo():
        def bar():
            print(spam)

        spam = 'ham'
        return bar

    b = foo()

    def test_function_closure(self):
        '''get_function_closure'''
        my_closure = six.get_function_closure(self.b)
        self.assertEqual(my_closure[0].cell_contents, 'ham')

    # Get the code object associated with func. This is equivalent to func.__code__ on Python 2.6+
    def test_function_code(self):
        '''get_function_code'''
        my_result = six.get_function_code(self.foo)
        self.assertIs(my_result, self.foo.__code__)

    def foo2(a=1,b=2):
        pass

    # Get the defaults tuple associated with func.
    def test_get_function_defaults(self):
        '''get_function_defaults'''
        my_result = six.get_function_defaults(self.foo2)
        self.assertEqual(my_result, (1, 2))

    # Get the globals of func.
    def test_get_function_globals(self):
        '''get_function_globals'''
        my_result = six.get_function_globals(self.foo2)
        self.assertIs(my_result, globals())

        '''
        six.create_unbound_method(func, cls)

        Return an unbound method object wrapping func. In Python 2, this will return a types.MethodType object. In
        Python 3, unbound methods do not exist and this wrapper will simply return func. 
        '''
    def test_create_unbound_method(self):
        '''create_unbound_method'''
        class X(object):
            pass

        def f(self):
            return self
        u = six.create_unbound_method(f, X)
        if six.PY2:
            self.assertIsInstance(u, types.MethodType)
        x = X()
        self.assertIs(f(x), x)

        '''
        six.create_bound_method(func, obj)

        Return a method object wrapping func and bound to obj. On both Python 2 and 3, this will return a
        types.MethodType object. The reason this wrapper exists is that on Python 2, the MethodType constructor requires
        the obj’s class to be passed. 
        '''
    def test_create_bound_method(self):
        '''create_bound_method'''
        class X(object):
            pass

        def f(self):
            return self
        x = X()
        b = six.create_bound_method(f, x)
        self.assertIsInstance(b, types.MethodType)
        self.assertIs(b(), x)

    def test_iterators_api(self):
        '''iterators' api'''
        my_dict = {'a':1,'b':2,'c':3}

        for item in six.iterkeys(my_dict):
            self.assertTrue(item)

        for item in six.itervalues(my_dict):
            self.assertTrue(item)

        for item in six.iteritems(my_dict):
            self.assertTrue(item)

        for item in six.viewkeys(my_dict):
            self.assertTrue(item)

        for item in six.viewvalues(my_dict):
            self.assertTrue(item)

        for item in six.viewitems(my_dict):
            self.assertTrue(item)

    #portable iterators: six.Iterator
    def test_portable_iterators(self):
        '''portable iterators'''

        class Test(six.Iterator):
            def __init__(self, init):
                self.init = init

            def __iter__(self):
                return self

            def __next__(self):
                self.init += 1
                return self.init

        x = Test(0)
        for num,item in enumerate(x):
            self.assertIsInstance(item, six.integer_types)
            if num>6:
                break
    #test decorators, @six.wraps, the result is that after decorating, the function's name is the name of itself, not the name of the decorator. 
    def test_decorators(self):
        '''decorators'''
        def my_dec(func):
            @six.wraps(func)
            def tmp(place_holder):
                print('call %s():' % func.__name__)
                return func(place_holder)
            return tmp

        @my_dec
        def now(place_holder):
            place_holder='1'
            print('place_holder is', place_holder)
            print('function now is running.')
        self.assertEqual(now.__name__,'now')

#category4 Syntax compatibility
class test_syntax_compatibility(unittest.TestCase):
    # test exec_()
    def test_exec_function(self):
        '''exec_ function'''
        i = 12
        j = 13
        six.exec_("global answer; answer=i*j")
        self.assertEqual(answer, 156)

    # test StringIO() and print_()
    def test_StringIO(self):
        '''StringIO and print_ function'''
        out = six.StringIO()
        six.print_(six.u("Hello,"), six.u("person!"), file=out)
        result = out.getvalue()
        self.assertIsInstance(result, six.text_type)
        self.assertEqual(result, six.u("Hello, person!\n"))

    #test metaclass
    def test_metaclass(self):
        '''metaclass'''
        from six import with_metaclass

        class Meta(type):
            pass

        class Base(object):
            pass

        class MyClass(with_metaclass(Meta, Base)):
            pass

        self.assertIsInstance(MyClass, six.class_types)

    def test_callable(self):
        '''callable'''
        class X:
            def __call__(self):
                pass
            def method(self):
                pass
        self.assertTrue( six.callable(X) )
        self.assertTrue( six.callable(X()) )
        self.assertTrue( six.callable(self.test_callable) )
        self.assertTrue( six.callable(hasattr) )
        self.assertTrue( six.callable(X.method) )
        self.assertTrue( six.callable(X().method) )
        self.assertFalse( six.callable(4) )
        self.assertFalse( six.callable("string") )

#category5 Renamed modules and attributes compatibility
class test_modules_compatibility(unittest.TestCase):
    def test_modules(self):
        '''modules'''
        from six.moves.queue import Queue
        self.assertIsInstance(Queue, six.class_types)
        from six.moves.configparser import ConfigParser
        self.assertIsInstance(ConfigParser, six.class_types)

if __name__ == '__main__':
    print('# '+sys.version)
    runner = tap.TAPTestRunner()
    runner.set_format("{short_description} (python " + sys.version.split()[0] + ")")
    runner.set_stream(True)
    unittest.main(testRunner=runner)
