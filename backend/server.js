const express = require('express');
const cors = require('cors');
const axios = require('axios');

const app = express();
const PORT = process.env.PORT || 3000;

// Enable CORS for all origins (you can restrict this later)
app.use(cors());

// Health check endpoint
app.get('/', (req, res) => {
    res.json({
        status: 'ok',
        message: 'BlackHole Jiosaavn Proxy Server',
        endpoints: ['/api/jiosaavn']
    });
});

// Proxy endpoint for Jiosaavn
app.get('/api/jiosaavn', async (req, res) => {
    try {
        const targetUrl = req.query.url;

        if (!targetUrl) {
            return res.status(400).json({ error: 'Missing url parameter' });
        }

        console.log('Proxying request to:', targetUrl);

        // Make request to Jiosaavn with proper headers
        const response = await axios.get(targetUrl, {
            headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                'Accept': 'application/json, text/plain, */*',
                'Accept-Language': 'en-US,en;q=0.9',
                'Referer': 'https://www.jiosaavn.com/',
                'Origin': 'https://www.jiosaavn.com',
            },
            timeout: 10000,
        });

        // Return the data
        res.json(response.data);
    } catch (error) {
        console.error('Proxy error:', error.message);

        if (error.response) {
            // Forward the error response from Jiosaavn
            res.status(error.response.status).json({
                error: 'Jiosaavn API error',
                status: error.response.status,
                message: error.message,
            });
        } else {
            // Network or other error
            res.status(500).json({
                error: 'Proxy server error',
                message: error.message,
            });
        }
    }
});

// Media Proxy endpoint for streaming audio/images
app.get('/api/media', async (req, res) => {
    try {
        const targetUrl = req.query.url;
        if (!targetUrl) return res.status(400).send('Missing url');

        // console.log('Proxying media request to:', targetUrl);

        const axiosConfig = {
            method: 'get',
            url: targetUrl,
            responseType: 'stream',
            headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                'Referer': 'https://www.jiosaavn.com/',
            }
        };

        if (req.headers.range) {
            axiosConfig.headers['Range'] = req.headers.range;
        }

        const response = await axios(axiosConfig);

        // Forward status and headers
        res.status(response.status);

        // Forward essential headers
        const headersToForward = [
            'content-type',
            'content-length',
            'content-range',
            'accept-ranges',
            'cache-control'
        ];

        headersToForward.forEach(header => {
            if (response.headers[header]) {
                res.set(header, response.headers[header]);
            }
        });

        // Set CORS explicitly
        res.set('Access-Control-Allow-Origin', '*');
        res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
        res.set('Access-Control-Allow-Headers', 'Range, User-Agent, Referer');
        res.set('Access-Control-Expose-Headers', 'Content-Range, Accept-Ranges, Content-Length, Content-Type');

        // Pipe the stream
        response.data.pipe(res);

        // Handle client disconnect
        req.on('close', () => {
            if (response.data && response.data.destroy) {
                response.data.destroy();
            }
        });
    } catch (error) {
        if (error.response && error.response.status === 416) {
            // Requested range not satisfiable
            return res.status(416).send('Requested range not satisfiable');
        }
        console.error('Media proxy error:', error.message);
        if (!res.headersSent) {
            res.status(500).send(error.message);
        }
    }
});

app.listen(PORT, () => {
    console.log(`BlackHole proxy server running on port ${PORT}`);
    console.log(`Health check: http://localhost:${PORT}/`);
    console.log(`Proxy endpoint: http://localhost:${PORT}/api/jiosaavn?url=<jiosaavn-url>`);
});
