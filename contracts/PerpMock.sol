// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {IPyth} from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import {PythStructs} from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

contract PerpMock is Ownable, Pausable {
  
    struct Order {
        uint256 timestamp;
        uint256 amount;
        int64 price;
        uint256 publishTime;
    }


    IPyth private _pyth;
    uint256 public orderId;
    address public immutable gelatoMsgSender;

    mapping(uint256 => Order) ordersByOrderId;

    event setOrderEvent(uint256 timestamp, uint256 orderId);

    modifier onlyGelatoMsgSender() {
        require(
            msg.sender == gelatoMsgSender,
            "Only dedicated gelato msg.sender"
        );
        _;
    }

    constructor(address _gelatoMsgSender, address pythContract) {
        gelatoMsgSender = _gelatoMsgSender;
        _pyth = IPyth(pythContract);
    }

    /* solhint-disable-next-line no-empty-blocks */
    receive() external payable {}

    function setOrder(uint256 _amount) external {
        orderId+=1;
        ordersByOrderId[orderId]= Order(block.timestamp,_amount,0,0);
        emit setOrderEvent(block.timestamp, orderId);      

    }

    function updatePrice(
        bytes[] memory updatePriceData,
        uint256[] memory orders
    ) external onlyGelatoMsgSender {
        uint256 fee = _pyth.getUpdateFee(updatePriceData);
        _pyth.updatePriceFeeds{value: fee}(updatePriceData);
        /* solhint-disable-next-line */
        bytes32 priceID = bytes32(
            0xca80ba6dc32e08d06f1aa886011eed1d77c77be9eb761cc10d72b7d0a2fd57a6
        );

        PythStructs.Price memory checkPrice = _pyth.getPriceUnsafe(priceID);
      
        for (uint256 i = 0; i < orders.length; i++) {
            Order storage order = ordersByOrderId[orders[i]];
            require(
                order.timestamp + 12 < checkPrice.publishTime,
                "NOT 12 sec elapsed"
            );

            order.price = checkPrice.price;
            order.publishTime = checkPrice.publishTime;
            }
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function withdraw() external onlyOwner returns (bool) {
        (bool result, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        return result;
    }

    function getOrder(uint256 _order) public view returns (Order memory) {
        return ordersByOrderId[_order];
    }
}
