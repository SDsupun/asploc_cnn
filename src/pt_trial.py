import os
import sys
import torch

# For NNI use relative import for user-defined modules
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__)) + '/../'
sys.path.append(SCRIPT_DIR)

from pt_lenet_model import PtLeNetModel


def trial(hparams):
    """
    Trial Script:
      - Initiate Model
      - Train
      - Test
      - Report
    """
    model = PtLeNetModel(
        filter_size = hparams['filter_size'],
        kernel_size = hparams['kernel_size'],
        l1_size = hparams['l1_size']
    )
    model.train_model(
        batch_size = hparams['batch_size'],
        learning_rate = hparams['learning_rate']
    )
    accuracy = model.test_model()
    print(f"The test accuracy is {accuracy}")
    torch.save(model.state_dict(), "lenet_model.pth")


if __name__ == '__main__':
    # Manual HyperParameters
    hparams = {
        "learning_rate": 0.001,
        "batch_size": 256,
        "l1_size": 64,
        "kernel_size": 5,
        "filter_size": 32
        }

    trial(hparams)
