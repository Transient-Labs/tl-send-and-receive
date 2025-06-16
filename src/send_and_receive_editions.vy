# pragma version 0.4.1

"""
@title Send & Receive Editions
@author Transient Labs
@license AGPL-3.0-only
@custom:version 1.0.0
@notice Contract that receives ERC-1155 editions and in exchange, sends a single new edition to the sender.
@dev The contract is written to only be configured for a single output token, however multiple input token configurations are possible.
     For each token sent out, you can configure which token and what amount of that token is required.
     Example: token A can be redeemed by sending 2 of token B *or* 5 of token C.
     It is not possible to combine different input tokens with this contract. This is a design choice to enhance simplicity.
     Additionally, it is possible to cnfigure when the redemption opens and what supply there is of the redepmption token.
"""

from ethereum.ercs import IERC165
from snekmate.auth import ownable
from snekmate.utils import pausable

initializes: ownable
initializes: pausable
implements: IERC165
exports: ownable.__interface__

# Interfaces
interface IERC1155TL:
    def externalMint(token_id: uint256, addresses: DynArray[address, 200], amounts: DynArray[uint256, 200]): nonpayable
    def safeBatchTransferFrom(from_: address, to_: address, ids: DynArray[uint256, 200], values: DynArray[uint256, 200], data: Bytes[1024]): nonpayable

# Structs
struct InitConfig:
    contract_address: address
    token_id: uint256
    open_at: uint256
    max_supply: uint256

struct InputConfig:
    contract_address: address
    token_id: uint256
    amount: uint256

struct SettingsConfig:
    open_at: uint256
    max_supply: uint256

# Events
event InputConfigured:
    contract_address: indexed(address)
    token_id: indexed(uint256)
    amount: indexed(uint256)

# Constants
SUPPORTED_INTERFACES: constant(bytes4[2]) = [
    0x01FFC9A7, # the ERC-165 identifier for ERC-165.
    0x4E2312E0, # the ERC-165 identifier for ERC-1155 Receiver.
]

# Storage
contract_address: public(address)
token_id: public(uint256)
open_at: public(uint256)
max_supply: public(uint256)
num_redeemed: public(uint256)
input_amount: public(HashMap[address, HashMap[uint256, uint256]]) # input contract address + input token id -> input amount needed

@deploy
def __init__(init_config: InitConfig):
    ownable.__init__()
    pausable.__init__()

    self.contract_address = init_config.contract_address
    self.token_id = init_config.token_id
    self.open_at = init_config.open_at
    self.max_supply = init_config.max_supply


@external
@nonreentrant
def onERC1155Received(operator: address, from_: address, id: uint256, value_: uint256,  data: Bytes[1024]) -> bytes4:
    """
    @notice Function called when an ERC-1155 token is transferred to this contract. This handles the redemption. 
    @dev Requires the contract not to be paused
    """
    pausable._require_not_paused()

    self._process_input_token(msg.sender, id, value_, from_)

    return method_id("onERC1155Received(address,address,uint256,uint256,bytes)", output_type=bytes4)


@external
@nonreentrant
def onERC1155BatchReceived(
    operator: address,
    from_: address,
    ids: DynArray[uint256, 200],
    values: DynArray[uint256, 200],
    data: Bytes[1024],
) -> bytes4:
    """
    @notice Function called when a batch of ERC-1155 tokens are transferred to this contract. This handles the redemption.
    @dev Requires the contract not to be paused
    """
    pausable._require_not_paused()

    assert len(ids) == len(values), "mismatch in ids array and values array"
    for i: uint256 in range(len(ids), bound=200):
        self._process_input_token(msg.sender, ids[i], values[i], from_)

    return method_id("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)", output_type=bytes4)
    

@internal
def _process_input_token(input_contract_address: address, input_token_id: uint256, input_amount: uint256, recipient: address):
    """
    @notice Helper function to process an input token
    """
    # Make sure that the redemption is open
    assert block.timestamp >= self.open_at, "send_and_receive_editions: redemption not open"

    # Get input amount needed to redeem
    required_input_amount: uint256 = self.input_amount[input_contract_address][input_token_id]
    assert required_input_amount > 0, "send_and_receive_editions: invalid input token"
    assert input_amount == required_input_amount, "send_and_receive_editions: invalid amount of token sent"

    # Make sure there is enough supply remaining
    assert self.num_redeemed < self.max_supply, "send_and_receive_editions: no supply remaining"

    # Adjust supply by one
    self.num_redeemed += 1

    # Mint token
    output_contract: IERC1155TL = IERC1155TL(self.contract_address)
    addresses: DynArray[address, 200] = [recipient]
    amounts: DynArray[uint256, 200] = [1]
    extcall output_contract.externalMint(self.token_id, addresses, amounts)


@external
def config_inputs(configs: DynArray[InputConfig, 100]):
    """
    @notice Function to set input amounts
    @dev Requires the owner to call the function
    """
    ownable._check_owner()

    for config: InputConfig in configs:
        self.input_amount[config.contract_address][config.token_id] = config.amount
        log InputConfigured(
            contract_address=config.contract_address, 
            token_id=config.token_id,
            amount=config.amount
        )

@external
def config_settings(config: SettingsConfig):
    """
    @notice Function to adjust contract settings
    @dev Requires the owner to call the function
    """
    ownable._check_owner()

    assert config.max_supply >= self.num_redeemed, "send_and_receive_editions: cannot set max supply below number redeemed"
    
    self.open_at = config.open_at
    self.max_supply = config.max_supply


@external
def withdraw_nfts(contract_address: address, token_ids: DynArray[uint256, 200], amounts: DynArray[uint256, 200], recipient: address):
    """
    @notice Function to withdraw all tokens in the contract to a particular recipient
    @dev Only the owner of the contract can call this
    """
    ownable._check_owner()

    erc1155tl: IERC1155TL = IERC1155TL(contract_address)
    extcall erc1155tl.safeBatchTransferFrom(self, recipient, token_ids, amounts, b"")


@external 
def set_paused(pause: bool):
    """
    @notice Function to pause/unpause the contract
    """
    ownable._check_owner()

    if (pause):
        pausable._pause()
    else:
        pausable._unpause()
    

@view
@external
def supportsInterface(interface_id: bytes4) -> bool:
    return interface_id in SUPPORTED_INTERFACES
    
