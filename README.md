# MartyDig SPF Survey

This Bash script is a robust tool for analyzing and visualizing SPF (Sender Policy Framework) records for domains. It recursively fetches SPF records, parses their components (e.g., include, a, ip4, ip6), and maps associated IP addresses. With its hierarchical tree output, it shows detailed relationships between domains, including IP addresses, CIDR ranges, and nested SPF inclusions. This script is ideal for email administrators, domain owners, and security professionals seeking to understand or audit complex SPF configurations.

Key Features:

** Recursive SPF Resolution: Follows include mechanisms to display a full SPF tree.

** IP Tracking: Maps IP addresses to domains and detects duplicate usage across SPF configurations.

** Mechanism Breakdown: Distinguishes and resolves a, ip4, and ip6 mechanisms to identify associated IPs and CIDR blocks.

** Diagnostics: Highlights domains with missing SPF records and reports duplicate IPs for better debugging and SPF optimization.