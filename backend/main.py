from fastapi import FastAPI, File, UploadFile
from fastapi.responses import JSONResponse
import torch
from torchvision import models, transforms
from PIL import Image
import io
import json

# Initialize FastAPI app
app = FastAPI()

# Load the pre-trained ResNet-18 model
model = models.resnet50(pretrained=True)
model.eval()  # Set the model to evaluation mode

# Define the image transformations for preprocessing
preprocess = transforms.Compose([
    transforms.Resize(256),
    transforms.CenterCrop(224),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
])

# Load the ImageNet class labels (for ResNet)
with open("class_index.json") as f:
    LABELS = json.load(f)#{i: label[1] for i, label in requests.get(LABELS_URL).json().items()}
label_table = {}
for i in range(1000):
    label_table[i] = LABELS[f'{i}'][1]
@app.post("/predict/")
async def predict(file: UploadFile = File(...)):
    try:
        # Read the image file as bytes
        image_bytes = await file.read()
        image = Image.open(io.BytesIO(image_bytes)).convert("RGB")

        # Preprocess the image
        input_tensor = preprocess(image)
        input_batch = input_tensor.unsqueeze(0)  # Add batch dimension

        # Run inference
        with torch.no_grad():  # Disable gradient computation
            outputs = model(input_batch)
        
        # Get top 5 predictions
        _, indices = torch.topk(outputs, 20)  # Get the top 5 classes
        probs = torch.nn.functional.softmax(outputs, dim=1)
        top_probs = probs[0, indices[0]].tolist()
        top_classes = [label_table[idx.item()] for idx in indices[0]]

        # Prepare the result as a list of (class_name, confidence_score)
        predictions = [{"label": label, "confidence": round(prob, 4)} for label, prob in zip(top_classes, top_probs)]
        print(predictions)
        return JSONResponse(content={"predictions": predictions})

    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8099)
