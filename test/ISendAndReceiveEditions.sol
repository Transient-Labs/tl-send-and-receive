// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.22;

import {IERC1155Receiver} from "@openzeppelin-contracts-5.0.2/token/ERC1155/IERC1155Receiver.sol";

interface ISendAndReceiveEditions is IERC1155Receiver {
    // Structs
    struct InitConfig {
        address contract_address;
        uint256 token_id;
        uint256 open_at;
        uint256 max_supply;
    }

    struct InputConfig {
        address contract_address;
        uint256 token_id;
        uint256 amount;
    }

    struct SettingsConfig {
        uint256 open_at;
        uint256 max_supply;
    }

    // Functions
    function owner() external view returns (address);
    function contract_address() external view returns (address);
    function token_id() external view returns (uint256);
    function open_at() external view returns (uint256);
    function max_supply() external view returns (uint256);
    function num_redeemed() external view returns (uint256);
    function transfer_ownership(address newOwner) external;
    function renounce_ownership() external;
    function config_inputs(InputConfig[] memory configs) external;
    function config_settings(SettingsConfig memory config) external;
    function withdraw_nfts(
        address contract_address,
        uint256[] memory token_ids,
        uint256[] memory amounts,
        address recipient
    ) external;
    function set_paused(bool pause) external;
    function get_input_config(address contract_address, uint256 token_id) external view returns (uint256);
}
