import bs4 as bs
with open ("testpage.html") as file:
    source = file.read()

soup=bs.BeautifulSoup(source,'lxml')
assert soup.title.string=='Python Programming Tutorials'