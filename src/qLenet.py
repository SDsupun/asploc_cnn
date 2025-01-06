import numpy as np

def fs256_quantize(X:np.matrix) -> np.matrix:
    # Fix scale
    scale = 256

    # Quantize
    X_quant = np.round(scale * X)

    return X_quant.astype(np.int16)

def fs256_dequantize(X:np.matrix) -> np.matrix:
    # Fix scale
    scale = 256

    # Quantize
    X_quant = np.round(X/scale)

    return X_quant.astype(np.int16)


class QLeNet():
    def __init__(self):
        # 1 input image channel, 6 output channels, 5x5 square conv kernel
        with open('../data/np_data/cnv1wq.npy', 'rb') as f:
            conv_layer_1w = np.load(f)
        with open('../data/np_data/cnv1bq.npy', 'rb') as f:
            conv_layer_1b = np.load(f)
        with open('../data/np_data/cnv2wq.npy', 'rb') as f:
            conv_layer_2w = np.load(f)
        with open('../data/np_data/cnv2bq.npy', 'rb') as f:
            conv_layer_2b = np.load(f)
        with open('../data/np_data/den1wq.npy', 'rb') as f:
            dense_1_w = np.load(f)
        with open('../data/np_data/den1bq.npy', 'rb') as f:
            dense_1_b = np.load(f)
        with open('../data/np_data/den2wq.npy', 'rb') as f:
            dense_2_w = np.load(f)
        with open('../data/np_data/den2bq.npy', 'rb') as f:
            dense_2_b = np.load(f)
        with open('../data/np_data/den3wq.npy', 'rb') as f:
            dense_3_w = np.load(f)
        with open('../data/np_data/den3bq.npy', 'rb') as f:
            dense_3_b = np.load(f)
        self.conv1 = self.Conv2d(1, 6, 5, conv_layer_1w, conv_layer_1b)
        self.conv2 = self.Conv2d(6, 16, 5, conv_layer_2w, conv_layer_2b)
        self.fc1 = self.myDense2d(dense_1_w, dense_1_b)
        self.fc2 = self.myDense2d(dense_2_w, dense_2_b)
        self.fc3 = self.myDense2d(dense_3_w, dense_3_b)
    
    def Conv2d(self, inChan:int, outChan:int, kernalDim:int, weight: np.ndarray, bias: np.ndarray):
        myIn = inChan
        myOt = outChan
        myKr = kernalDim
        myWeight = weight
        myBias = bias

        def CalConv2d(img:np.ndarray) -> np.ndarray:
            inDim, imdim_r, imdim_c = img.shape
            outImg = np.zeros((myOt, imdim_r-myKr, imdim_c-myKr))
            for oc in range(myOt):
                bias_s = myBias[oc]
                for ic in range(myIn):
                    kernal = myWeight[oc][ic]
                    for kr_i in range(int(imdim_r-myKr)):
                        for kr_j in range(int(imdim_c-myKr)):
                            outImg[oc][kr_i][kr_j] += (kernal * img[ic][kr_i:kr_i+myKr,kr_j:kr_j+myKr]).sum() + bias_s
            return outImg
        return CalConv2d
    
    def myRelu(self, img:np.ndarray) -> np.ndarray:
        return img.clip(0)
    
    def maxPool2d(self, img:np.ndarray) -> np.ndarray:
        inDim, imdim_r, imdim_c = img.shape
        outImg = np.zeros_like(img, shape=(inDim, int((imdim_r+1)/2), int((imdim_c+1)/2)))
        for chn in range(inDim):
            for i in range(int((imdim_r+1)/2)):
                for j in range(int((imdim_c+1)/2)):
                    if(i*2 > imdim_r):
                        if(j*2 > imdim_c):
                            outImg[chn][i,j] = img[chn][i*2,j*2]
                        else:
                            outImg[chn][i,j] = (img[chn][i*2,j*2:j*2+2]).max()
                    else:
                        if(j*2 > imdim_c):
                            outImg[chn][i,j] = (img[chn][i*2:i*2+2,j*2]).max()
                        else:
                            outImg[chn][i,j] = (img[chn][i*2:i*2+2,j*2:j*2+2]).max()
        return outImg

    def myReshape(self, img:np.ndarray) -> np.ndarray:
        return np.reshape(img, (img.size, -1))
    
    def myDense2d(self, weight:np.ndarray, bias:np.ndarray) -> np.ndarray:
        myweight = weight
        mybias  = bias

        def dense(img:np.ndarray):
            return np.dot(myweight, img) +  mybias
        return dense

    def qLenet_forward(self, x:np.ndarray):
        x = self.maxPool2d(self.myRelu(self.conv1(x)))
        x = fs256_dequantize(x)
        x = self.maxPool2d(self.myRelu(self.conv2(x)))
        x = fs256_dequantize(x)
        x = self.myReshape(x)
        x = self.myRelu(self.fc1(x))
        x = fs256_dequantize(x)
        x = self.myRelu(self.fc2(x))
        x = fs256_dequantize(x)
        x = self.fc3(x)
        x = fs256_dequantize(x)
        return x