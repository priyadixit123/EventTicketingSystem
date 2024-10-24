// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract EventTicketing is ERC721, Ownable {
    uint256 public totalTickets;
    uint256 public ticketsSold;
    uint256 public eventDate;
    uint256 public basePrice;
    uint256 public royaltyPercentage;

    struct Ticket {
        uint256 ticketId;
        uint256 price;
        address owner;
        bool isResellable;
        string ticketType; // General, VIP, etc.
    }

    mapping(uint256 => Ticket) public tickets;
    mapping(address => uint256[]) public userTickets;

    event TicketIssued(uint256 ticketId, address buyer, string ticketType, uint256 price);
    event TicketResold(uint256 ticketId, address from, address to, uint256 resalePrice);
    event TicketRefunded(uint256 ticketId, address ticketOwner, uint256 refundAmount);
    event TicketValidated(uint256 ticketId, address owner);
    
    constructor(
        string memory eventName, 
        uint256 _totalTickets, 
        uint256 _eventDate, 
        uint256 _basePrice,
        uint256 _royaltyPercentage
    ) ERC721(eventName, "ETIX") {
        require(_totalTickets > 0, "Total tickets should be greater than zero");
        require(_eventDate > block.timestamp, "Event date must be in the future");
        require(_basePrice > 0, "Base price must be greater than zero");
        require(_royaltyPercentage <= 100, "Royalty percentage cannot exceed 100");

        totalTickets = _totalTickets;
        eventDate = _eventDate;
        basePrice = _basePrice;
        royaltyPercentage = _royaltyPercentage;
    }

    // Function to issue a ticket
    function issueTicket(address buyer, string memory ticketType, bool resellable) public onlyOwner {
        require(ticketsSold < totalTickets, "All tickets have been sold");
        uint256 ticketId = ticketsSold + 1;
        tickets[ticketId] = Ticket(ticketId, basePrice, buyer, resellable, ticketType);
        userTickets[buyer].push(ticketId);

        _mint(buyer, ticketId);
        ticketsSold++;

        emit TicketIssued(ticketId, buyer, ticketType, basePrice);
    }

    // Function for ticket resale
    function resellTicket(uint256 ticketId, uint256 resalePrice, address newOwner) public {
        require(ownerOf(ticketId) == msg.sender, "Only the ticket owner can resell");
        require(tickets[ticketId].isResellable, "Ticket is not resellable");
        require(newOwner != address(0), "New owner address is invalid");

        // Calculate royalty and transfer
        uint256 royalty = (resalePrice * royaltyPercentage) / 100;
        payable(owner()).transfer(royalty);

        // Transfer ticket to new owner
        _transfer(msg.sender, newOwner, ticketId);
        tickets[ticketId].price = resalePrice;
        tickets[ticketId].owner = newOwner;

        // Update ticket ownership in mapping
        _removeTicketFromUser(msg.sender, ticketId);
        userTickets[newOwner].push(ticketId);

        emit TicketResold(ticketId, msg.sender, newOwner, resalePrice);
    }

    // Function for dynamic pricing (price increases as tickets sell out)
    function getDynamicPrice() public view returns (uint256) {
        return basePrice + (basePrice * ticketsSold) / totalTickets;
    }

    // Function for event organizer to validate a ticket
    function validateTicket(uint256 ticketId) public onlyOwner {
        require(ownerOf(ticketId) != address(0), "Invalid ticket ID");
        emit TicketValidated(ticketId, ownerOf(ticketId));
    }

    // Refund ticket
    function refundTicket(uint256 ticketId) public onlyOwner {
        address ticketOwner = ownerOf(ticketId);
        uint256 refundAmount = tickets[ticketId].price;

        _burn(ticketId);
        payable(ticketOwner).transfer(refundAmount);

        emit TicketRefunded(ticketId, ticketOwner, refundAmount);
    }

    // Remove ticket from user list (internal function)
    function _removeTicketFromUser(address user, uint256 ticketId) internal {
        uint256 length = userTickets[user].length;
        for (uint256 i = 0; i < length; i++) {
            if (userTickets[user][i] == ticketId) {
                userTickets[user][i] = userTickets[user][length - 1];
                userTickets[user].pop();
                break;
            }
        }
    }

    // Fallback function to receive funds for ticket sales
    receive() external payable {}
}
