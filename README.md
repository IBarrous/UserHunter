# UserHunter
<h3>Description:</h3>
UserHunter is a bash script designed to enumerate domain-joined computers to gain initial access to an Active Directory (AD) environment. It relies on various techniques such as Null Sessions, OSINT, Username Brute Forcing, AS-REP Roasting, and Password Spraying.

<h3>Usage:</h3>
<pre><code>chmod +x UserHunter.sh</code></pre>
<pre><code>./UserHunter.sh [--target] [--domain] [OPTIONS]</code></pre>
<h3>Options:</h3>
<ul>
  <li>-t, --target : Specify the target IP address</li>
  <li>-d, --domain : Specify the domain</li>
  <li>-c, --company-name : Specify the company name (optional)</li>
  <li>-ul, --usernames-list : Specify the usernames list to brute force (optional)</li>
  <li>-pl, --passwords-list : Specify the password list (optional)</li>
  <li>-h, --help : Display this help message</li>
</ul>
<h3>Details:</h3>
<ul>
<li>UserHunter enumerates usernames with LDAP null bind, SMB Null Sessions and RPC Null Sessions. If the previous techniques result in failure, it runs an OSINT operation based on the targeted organization's name to gather a list of employee usernames. It also performs a Username Brute Forcing operation if all previous methods fail.</li>
<li>With the valid list of usernames, UserHunter performs an AS-REP Roasting Attack on the domain. If the prior attack fails, it fetches the password policy from the domain and runs a Password Spraying attack on the found usernames.</li>
</ul>

<p align="center"><i>Example of successful enumeration with null sessions and successful AS-REP Roasting</i></p>

![first](https://github.com/IBarrous/UserHunter/assets/126162952/0213352d-6986-4845-8555-c8d6f0b7999b)

<p align="center"><i>Example of successful OSINT operation and successful Password Spraying</i></p>

![second](https://github.com/IBarrous/UserHunter/assets/126162952/8d11bfa9-a860-462c-8bd7-0a78cdd8681b)

<h3>Resources:</h3>
<ul>
  <li>SMB Null Session: crackmapexec</li>
  <li>RPC Null Session: rpcclient
  <li>LDAP Null Bind: ldapsearch</li>
  <li>OSINT UserNames Collector: <a href="https://github.com/m8sec/CrossLinked/">crosslinked</a></li>
  <li>OSINT SurNames Generator: <a href="https://github.com/w0Tx/generate-ad-username">ADGenerator</a></li>
  <li>Usernames Brute Force: <a href="https://github.com/ropnop/kerbrute">kerbrute</a></li>
  <li>AS-REP Roasting: <a href="https://github.com/fortra/impacket/blob/master/examples/GetNPUsers.py">Impacket-GetNPUsers</a></li>
  <li>Password Spraying: <a href="https://github.com/GabrielDuschl/Automated-CME-Password-Spraying">CME-Password-Spraying</a></li>
</ul>
