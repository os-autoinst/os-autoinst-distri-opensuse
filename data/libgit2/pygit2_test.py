import pygit2

url = "https://github.com/libgit2/libgit2"
path = "./libgit2_clone"

try:
    pygit2.clone_repository(url, path)
    print("Repository cloned successfully to {}".format(path))
except Exception as e:
    print("Error: {}".format(e))
