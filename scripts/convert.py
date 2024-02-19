import re

f = open("test.ini","r")
f1 = open("output.ini","w")
lines = f.readlines()
x = ""
for line in lines:
    if re.search(r'^\[',line):
        x = line.strip()
    elif len(line) > 1:
        s = "{} {}".format(x,line)
        s1 = re.sub(r"[\[\]=]","",s)
        s1 = re.sub(r"\ \ ","",s1)
        f1.write(s1)
        
f.close()
f1.close()