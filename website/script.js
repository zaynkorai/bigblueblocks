document.addEventListener('DOMContentLoaded', () => {
    const gridContainer = document.querySelector('.grid-container');
    const cols = 10;
    const rows = 10;

    // Create Grid Nodes
    for (let i = 0; i < cols * rows; i++) {
        const node = document.createElement('div');
        node.classList.add('grid-node');
        gridContainer.appendChild(node);
    }

    const nodes = document.querySelectorAll('.grid-node');

    // Random Grid Capture Animation
    function animateGrid() {
        const randomIndex = Math.floor(Math.random() * nodes.length);
        const node = nodes[randomIndex];

        // Pick a random color from the app's official theme
        const colors = ['#00F0FF', '#FFC900', '#BC13FE', '#FF5E00', '#2E7DFF'];
        const randomColor = colors[Math.floor(Math.random() * colors.length)];

        node.style.background = randomColor;
        node.style.border = `1px solid ${randomColor}`;

        setTimeout(() => {
            node.style.background = 'rgba(255, 255, 255, 0.03)';
            node.style.border = '1px solid rgba(255, 255, 255, 0.05)';
        }, 3000);
    }

    setInterval(animateGrid, 300);

    // Initial Capture
    for (let i = 0; i < 5; i++) animateGrid();
});
