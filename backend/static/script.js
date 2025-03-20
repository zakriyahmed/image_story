const fileInput = document.getElementById('fileInput');
const predictButton = document.getElementById('predictButton');
const resultsDiv = document.getElementById('results');

predictButton.addEventListener('click', async () => {
    const file = fileInput.files[0];
    if (!file) {
        resultsDiv.textContent = "Please select an image.";
        return;
    }

    const formData = new FormData();
    formData.append('file', file);

    try {
        const response = await fetch('/predict/', {
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
    resultsDiv.innerHTML = ''; // Clear previous results

    if (data.caption) {
        const captionElement = document.createElement('p');
        captionElement.textContent = `Caption: ${data.caption}`;
        resultsDiv.appendChild(captionElement);
    }

    if (data.predictions && Array.isArray(data.predictions)) {
        const predictionsList = document.createElement('ul');
        data.predictions.forEach(prediction => {
            const listItem = document.createElement('li');
            listItem.textContent = `${prediction.label}: ${prediction.confidence}`;
            predictionsList.appendChild(listItem);
        });
        resultsDiv.appendChild(predictionsList);
    }
}