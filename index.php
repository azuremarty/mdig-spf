<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MartyDIG SPF Survey</title>
    <style>
        body {
            background-color: black;
            color: white;
            margin: 0;
            font-family: Arial, sans-serif;
            padding: 10px;
            box-sizing: border-box;
        }
        form {
            display: flex;
            flex-wrap: wrap;
            align-items: center;
            gap: 10px;
            max-width: 500px;
        }
        label {
            font-size: 1em;
        }
        input[type="text"] {
            padding: 8px;
            border: 1px solid #ddd;
            border-radius: 5px;
            flex: 1;
            min-width: 200px;
            box-sizing: border-box;
        }
        input[type="submit"] {
            background-color: #00aaff;
            color: white;
            border: none;
            padding: 10px;
            border-radius: 5px;
            cursor: pointer;
            font-size: 1em;
        }
        .output {
            white-space: pre-wrap;
            word-break: break-all;
            background-color: black;
            border: none;
            padding: 10px;
            font-family: monospace;
            margin-top: 0px;
            font-size: 1em;
        }
        .error {
            color: red;
        }
        .bold { font-weight: bold; }
        .color-red { color: #ff5555; }
        .color-blue { color: #00aaff; }
        .color-yellow { color: #ffff00; }
        .color-orange { color: #ff9500; }
        .color-green { color: #00ff00; }
        .color-cyan { color: #00ffff; }
        .color-purple { color: #ff00ff; }
        .color-white { color: white; }
    </style>
</head>
<body>
    <form id="dnsForm" method="get" action="index.php">
        <label for="domain">SPF Domain:</label>
        <input type="text" id="domain" name="d" value="<?php echo isset($_GET['d']) ? htmlspecialchars($_GET['d']) : ''; ?>" required>
        <div id="submit-container">
            <input type="submit" value="Submit">
            <!-- Link to the script in a new window -  -->
            <a href="https://scripts.martypete.com/spfsurvey/scripts/index.php" target="_blank" class="icon-link">
                <!-- new window icon -->
                <img src="https://martypete.com/wp-content/uploads/2024/07/new-window.256x256.png" alt="Open in new tab" style="width: 24px; height: 24px;">
            </a>
        </div>
    </form>

    <?php
    if (isset($_GET['d'])) {
        // Set the domain value from GET and trim whitespace
        $domain = trim($_GET['d']);

        // Validate the domain format
        if (filter_var($domain, FILTER_VALIDATE_DOMAIN, FILTER_FLAG_HOSTNAME)) {
            // Optionally set the TERM environment variable
            putenv('TERM=xterm');  // This helps some scripts behave more predictably when not in a terminal

            // Sanitize the input to avoid security issues
            $domain = escapeshellarg($domain);

            // Path to your bash script
            // MAKE SURE TO RUN: chmod -R +x scripts/
            $script = 'scripts/spf.sh';

            // Execute the bash script and capture the output
            $output = shell_exec("$script $domain 2>&1");

            // Map ANSI codes to HTML
            $ansiToHtml = [
                '/\033\[1;37m/' => '<span class="bold">',
                '/\033\[1;31m/' => '<span class="color-red">',
                '/\033\[1;34m/' => '<span class="color-blue">',
                '/\033\[1;33m/' => '<span class="color-yellow">',
                '/\033\[1;30m/' => '<span class="color-orange">',
                '/\033\[1;32m/' => '<span class="color-green">',
                '/\033\[1;36m/' => '<span class="color-cyan">',
                '/\033\[1;35m/' => '<span class="color-purple">',
                '/\033\[0m/'    => '<span class="color-white">',
                // Add any other necessary mappings here
            ];

            // Replace ANSI codes with HTML
            $outputClean = $output;
            foreach ($ansiToHtml as $ansi => $html) {
                $outputClean = preg_replace($ansi, $html, $outputClean);
            }

            // Display the cleaned output
            if ($outputClean) {
                echo "<pre class='output'>$outputClean</pre>";
            } else {
                echo "<h2 class='error'>No results found or an error occurred.</h2>";
            }
        } else {
            echo "<h2 class='error'>Invalid domain format.</h2>";
        }
    }
    ?>
        <!-- JavaScript to focus on the input field -->
        <script type="text/javascript">
        window.onload = function() {
           document.getElementById("domain").focus();
       };
    </script>
        <script>
        document.addEventListener('selectionchange', () => {
            const selection = window.getSelection();
            const selectedText = selection.toString();

            if (selectedText) {
                navigator.clipboard.writeText(selectedText)
                    .then(() => {
                        showNotification(`Copied: "${selectedText}"`);
                    })
                    .catch(err => console.error('Error copying text to clipboard:', err));
            }
        });

        function showNotification(message) {
            // Create notification element
            const notification = document.createElement('div');
            notification.textContent = message;
            notification.style.position = 'fixed';
            notification.style.bottom = '20px';
            notification.style.right = '20px';
            notification.style.backgroundColor = '#333';
            notification.style.color = '#fff';
            notification.style.padding = '10px 20px';
            notification.style.borderRadius = '5px';
            notification.style.boxShadow = '0 4px 6px rgba(0,0,0,0.1)';
            notification.style.zIndex = '1000';
            notification.style.opacity = '1';
            notification.style.transition = 'opacity 0.5s ease';

            // Add to body
            document.body.appendChild(notification);

            // Remove after 2 seconds
            setTimeout(() => {
                notification.style.opacity = '0';
                setTimeout(() => notification.remove(), 500);
            }, 2000);
        }
    </script>
</body>
</html>
