*Originally a product of w2c/letsencrypt-esxi. Modified for those of us that are either unable or unwilling to expose our ESXi management interfaces to the Internet.*

# Let's Encrypt for VMware ESXi

`acme-esxi` is a lightweight open-source solution to automatically obtain and renew Let's Encrypt or private ACME CA certificates on standalone VMware ESXi servers. Packaged as a _VIB archive_ or _Offline Bundle_, install/upgrade/removal is possible directly via the web UI or, alternatively, with just a few SSH commands.

Features:

- **Fully-automated**: Requesting and renewing certificates without user interaction
- **Auto-renewal**: A cronjob runs once a week to check if a certificate is due for renewal
- **Persistent**: The certificate, private key and all settings are preserved over ESXi upgrades
- **Configurable**: Customizable parameters for renewal interval, Let's Encrypt (ACME) backend, etc
- **Can be used with any ACME CA**: [LabCA](https://github.com/hakwerk/labca) is a great example.

_Successfully tested with all currently supported versions of ESXi (6.5, 6.7, 7.0)._

## Troubleshooting

See the [Wiki](https://github.com/NateTheSage/acme-esxi/wiki) for possible pitfalls and solutions.

## License

    acme-esxi is free software;
    you can redistribute it and/or modify it under the terms of the
    GNU General Public License as published by the Free Software Foundation,
    either version 3 of the License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
