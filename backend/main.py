from fastapi import FastAPI, File, UploadFile, Response, Form
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware

from fastapi.responses import JSONResponse
import torch
from torchvision import models, transforms
from PIL import Image
import io
import json
import google.generativeai as genai


def generate_caption_with_gemini_text(top_labels_with_probs,tags=None):
    if len(tags)<1:
        user_tags=['None']
    else:
        user_tags = tags
    
    prompt_text = f"The image contains the following identified objects and features with associated likelihood using resnet50 model: {', '.join([f'{label} ({prob:.2f})' for label, prob in top_labels_with_probs[:30]])}. The user provided following tags as context to image {user_tags}. Please generate an artistic caption about the image to be put on instagram, just one."

    try:
        response = model_txt.generate_content(prompt_text)
        response.resolve()
        if response.text:
            return response.text
        else:
            print("No text generated in the response.")
            return None
    except Exception as e:
        print(f"Error generating caption with Gemini Pro: {e}")
        return None



# Initialize FastAPI app
app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Replace with specific origins in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Load the pre-trained ResNet-18 model
model = models.resnet50(pretrained=True)
model.eval()  # Set the model to evaluation mode

genai.configure(api_key="xxxx")  # Replace with your actual API key

# Use the Gemini Pro model (text-only)
model_txt = genai.GenerativeModel('gemini-2.0-flash')

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
async def predict(file: UploadFile = File(...) , tags: str = Form(...)):
    try:
        # Read the image file as bytes
        
        image_bytes = await file.read()
        #print(image_bytes,tags,file)
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
        predi = [(label,round(prob,4)) for label, prob in zip(top_classes, top_probs)]
        if len(tags)<1:
            tag_list = ['None']
        else:
            tag_list = tags
        generated_caption = generate_caption_with_gemini_text(predi,tag_list)
        #return JSONResponse(content={"predictions": predictions})
        return JSONResponse(content={"predictions": predictions, "caption": generated_caption})

    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8099)
