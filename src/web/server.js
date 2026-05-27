import express from 'express'
import path from 'path'
import { fileURLToPath } from 'url'
import dotenv from 'dotenv'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

const app = express();


dotenv.config();

// For demo purpose, shouldn't be used in production
app.use('/lib/msal', express.static('node_modules/@azure/msal-browser/lib'))
app.use('/lib/applicationinsights',express.static('node_modules/@microsoft/applicationinsights-web/dist/es5'))
app.use('/lib/marked', express.static('node_modules/marked'))
app.use(express.static(__dirname));

const port = process.env.PORT || 3000;

app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname,'/index.html'));
});

app.get('/config',(req, res) => {
    res.json({
        apiUrl: process.env.API_URL,
        appInsightKey: process.env.APP_INSIGHT_KEY        
    });
});

app.listen(port,() => {
    console.log(`Listening on port ${port}`);
});