const { exec } = require('child_process');
const fs = require('fs');

console.log("🔭 Watching for new Technical Designs from GitHub...");

// Configuration
const CHECK_INTERVAL = 10000; // Check every 10 seconds

function gitPull() {
    exec('git pull', (error, stdout, stderr) => {
        if (error) {
            console.error(`Error: ${error.message}`);
            return;
        }
        if (stdout.includes('Already up to date.')) {
            // Do nothing, just wait
        } else {
            console.log("🚀 New Design Detected! Syncing...");
            console.log(stdout);
            
            // OPTIONAL: Trigger a notification or sound here
            console.log("✅ Ready for Agentforce VIBE processing.");
        }
    });
}

// Run loop
setInterval(gitPull, CHECK_INTERVAL);
gitPull(); // Run immediately on start