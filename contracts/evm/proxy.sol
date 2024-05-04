// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Imports
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @title MemBridgeProxy contract
/// @notice Proxy contract for the MEM Bridge contract
/// @dev Implements transparent upgradeability for the MEM Bridge contract
/// @author charmful0x
/// @custom:security-contact darwin@decent.land
contract MemBridgeProxy {
    address public admin;
    address public proxy;
    constructor(address _implementation) {
        ProxyAdmin adminInstance = new ProxyAdmin(msg.sender);
        admin = address(adminInstance);
        TransparentUpgradeableProxy proxyInstance = new TransparentUpgradeableProxy(
                _implementation,
                admin,
                ""
            );
        proxy = address(proxyInstance);
    }
}
