import os
import sys
import re

for fname in sys.argv[1:]:
  print(f"Fixing f2c {fname}")
  fileData=open(fname).read()
  doneFixes=False
  while True:
    fromPattern='/* Subroutine */ int'
    toPattern='/* Subroutine */ void'
    before,at,after=fileData.partition(fromPattern)
    if len(at)==0:
      break
    doneFixes=True
    semiPos=after.find(";")
    bracePos=after.find("{")
    if semiPos>bracePos and bracePos>=0:
      # function definition - fix contents of braces
      endBracePos=bracePos+1
      braceLevel=1
      while braceLevel!=0:
        if after[endBracePos]=='{':
          braceLevel+=1
        if after[endBracePos]=='}':
          braceLevel-=1
        endBracePos+=1
      fnBody=after[bracePos:endBracePos]
#      print("Fix fn body: *****\n",fnBody,"*****\n\n",bracePos,endBracePos)

      fnBody=fnBody.replace("return 0","return")
      after=after[:bracePos]+fnBody+after[endBracePos:]
    # replace everything in the data
    fileData=before+toPattern+after
#  print(fileData)
  fileData,count=re.subn(r"(struct \{[^}]+\} debug_;)",r"static \1",fileData)
  if count>0:
    doneFixes=True
  fileData,count=re.subn(r"(struct \{[^}]+\} timing_;)",r"static \1",fileData)
  if count>0:
    doneFixes=True
  if doneFixes:
    print(f"Fixed: {fname}")
    os.rename(fname,fname+".orig")
    open(fname,"w").write(fileData)  
      
      

