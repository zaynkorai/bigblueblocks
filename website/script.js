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
        const shapeTypes = [
            [[0, 0]], // Dot
            [[0, 0], [1, 0], [0, 1], [1, 1]], // Square
            [[0, 0], [1, 0], [2, 0]], // 3x1 Line
            [[0, 0], [0, 1], [0, 2]], // 1x3 Line
            [[0, 0], [1, 0], [1, 1]], // L small
        ];

        const shape = shapeTypes[Math.floor(Math.random() * shapeTypes.length)];
        const startX = Math.floor(Math.random() * (cols - 2));
        const startY = Math.floor(Math.random() * (rows - 2));

        // Pick a random gradient from the official theme
        const gradients = [
            'var(--grad-green)',
            'var(--grad-yellow)',
            'var(--grad-orange)',
            'var(--grad-blue)',
            'var(--grad-red)',
            'var(--grad-hurdle)'
        ];
        const randomGrad = gradients[Math.floor(Math.random() * gradients.length)];

        shape.forEach(offset => {
            const x = startX + offset[0];
            const y = startY + offset[1];
            if (x >= 0 && x < cols && y >= 0 && y < rows) {
                const node = nodes[y * cols + x];
                node.style.background = randomGrad;
                node.style.border = `none`;
                node.style.borderRadius = '4px';
                node.style.boxShadow = '0 0 10px rgba(255, 255, 255, 0.1)';

                setTimeout(() => {
                    node.style.background = '';
                    node.style.border = '';
                    node.style.borderRadius = '';
                    node.style.boxShadow = '';
                }, 4000);
            }
        });
    }

    setInterval(animateGrid, 800);

    // Initial Capture
    for (let i = 0; i < 5; i++) animateGrid();
});
