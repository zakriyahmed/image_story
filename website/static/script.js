const fileInput = document.getElementById('fileInput');
const predictButton = document.getElementById('predictButton');
const resultsDiv = document.getElementById('results');
const tagInput = document.getElementById('tagInput');
const tagContainer = document.getElementById('tagContainer');
const uploadedImage = document.getElementById('uploadedImage');
let tags = [];

fileInput.addEventListener('change', () => {
    const file = fileInput.files[0];
    if (file) {
        uploadedImage.src = URL.createObjectURL(file);
    }
});

tagInput.addEventListener('keydown', (event) => {
    if (event.key === 'Enter' && tagInput.value.trim() !== '') {
        tags.push(tagInput.value.trim());
        renderTags();
        tagInput.value = '';
    }
});

function renderTags() {
    tagContainer.innerHTML = '';
    tags.forEach((tag, index) => {
        const tagElement = document.createElement('div');
        tagElement.className = 'tag';
        tagElement.textContent = tag;
        tagElement.addEventListener('click', () => {
            tags.splice(index, 1);
            renderTags();
        });
        tagContainer.appendChild(tagElement);
    });
}

predictButton.addEventListener('click', async () => {
    const file = fileInput.files[0];
    if (!file) {
        resultsDiv.textContent = "Please select an image.";
        return;
    }

    const formData = new FormData();
    formData.append('file', file);
    formData.append('tags', JSON.stringify(tags));

    try {
        const response = await fetch('http://13.53.197.9:8099/predict/', {
            method: 'POST',
            body: formData,
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const data = await response.json();
        displayResults(data);
    } catch (error) {
        console.error('Error:', error);
        resultsDiv.textContent = "An error occurred.";
    }
});

function displayResults(data) {
    resultsDiv.innerHTML = '';

    if (data.caption) {
        const captionElement = document.createElement('p');
        captionElement.textContent = `Caption: ${data.caption}`;
        resultsDiv.appendChild(captionElement);
    }

    if (data.predictions && Array.isArray(data.predictions)) {
        const predictionsContainer = document.createElement('div');
        predictionsContainer.className = 'prediction-container';

        data.predictions.forEach(prediction => {
            const predictionTag = document.createElement('div');
            predictionTag.className = 'prediction-tag';
            predictionTag.textContent = `${prediction.label}`;

            const fontSize = 12 + (prediction.confidence * 18);
            predictionTag.style.fontSize = `${fontSize}px`;

            predictionsContainer.appendChild(predictionTag);
        });

        resultsDiv.appendChild(predictionsContainer);
    }
}