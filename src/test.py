f = open('image_2.txt')
j = 0
img_row = ''
for l in f:
    if(j%32 == 0):
        print(f'{img_row}\n')
        img_row = ''
    else:
        img_row += l.replace("\n", "")
    j = j+1