from setuptools import setup, find_packages

setup(
    name='package',
    version='0.1',
    packages=find_packages(),
    entry_points={
        'console_scripts': [
            'hello-world=package.cli:hello',
        ],
    },
)
