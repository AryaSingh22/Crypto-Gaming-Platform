'use client';

import React, { useState, useEffect } from 'react';
import { 
  SparklesIcon, 
  ClockIcon, 
  TicketIcon, 
  TrophyIcon,
  CurrencyDollarIcon,
  UserGroupIcon,
  CalendarIcon,
  GiftIcon
} from '@heroicons/react/24/outline';
import { useAccount, useContractRead, useContractWrite, usePrepareContractWrite } from 'wagmi';

interface LotteryRound {
  id: number;
  startTime: number;
  endTime: number;
  prizePool: string;
  totalTickets: number;
  status: 'active' | 'drawing' | 'completed';
  winners?: string[];
}

interface UserTicket {
  roundId: number;
  ticketId: number;
  numbers: number[];
  purchaseTime: number;
}

export default function LotteryGame() {
  const { address, isConnected } = useAccount();
  const [selectedNumbers, setSelectedNumbers] = useState<number[]>([]);
  const [ticketCount, setTicketCount] = useState(1);
  const [activeTab, setActiveTab] = useState<'buy' | 'history' | 'winners'>('buy');

  // Mock data - replace with actual contract calls
  const currentRound: LotteryRound = {
    id: 15,
    startTime: Date.now() - 5 * 24 * 60 * 60 * 1000, // 5 days ago
    endTime: Date.now() + 2 * 24 * 60 * 60 * 1000, // 2 days from now
    prizePool: '125,000',
    totalTickets: 2847,
    status: 'active'
  };

  const userTickets: UserTicket[] = [
    {
      roundId: 15,
      ticketId: 1234,
      numbers: [7, 13, 21, 35, 42],
      purchaseTime: Date.now() - 2 * 60 * 60 * 1000
    },
    {
      roundId: 15,
      ticketId: 1235,
      numbers: [3, 18, 27, 39, 45],
      purchaseTime: Date.now() - 1 * 60 * 60 * 1000
    }
  ];

  const previousWinners = [
    { round: 14, address: '0x1234...5678', prize: '98,500 GAME', numbers: [5, 12, 23, 34, 41] },
    { round: 13, address: '0x2345...6789', prize: '87,200 GAME', numbers: [8, 17, 26, 33, 48] },
    { round: 12, address: '0x3456...7890', prize: '92,800 GAME', numbers: [2, 15, 29, 37, 44] }
  ];

  const ticketPrice = 10; // 10 GAME tokens per ticket
  const maxNumber = 49;
  const numbersToSelect = 5;

  const timeUntilDraw = currentRound.endTime - Date.now();
  
  const formatTimeRemaining = (ms: number) => {
    const days = Math.floor(ms / (1000 * 60 * 60 * 24));
    const hours = Math.floor((ms % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
    const minutes = Math.floor((ms % (1000 * 60 * 60)) / (1000 * 60));
    
    if (days > 0) return `${days}d ${hours}h ${minutes}m`;
    if (hours > 0) return `${hours}h ${minutes}m`;
    return `${minutes}m`;
  };

  const handleNumberSelect = (number: number) => {
    if (selectedNumbers.includes(number)) {
      setSelectedNumbers(selectedNumbers.filter(n => n !== number));
    } else if (selectedNumbers.length < numbersToSelect) {
      setSelectedNumbers([...selectedNumbers, number].sort((a, b) => a - b));
    }
  };

  const handleQuickPick = () => {
    const numbers: number[] = [];
    while (numbers.length < numbersToSelect) {
      const num = Math.floor(Math.random() * maxNumber) + 1;
      if (!numbers.includes(num)) {
        numbers.push(num);
      }
    }
    setSelectedNumbers(numbers.sort((a, b) => a - b));
  };

  const totalCost = ticketCount * ticketPrice;
  const canBuyTickets = selectedNumbers.length === numbersToSelect && isConnected;

  const NumberGrid = () => (
    <div className="grid grid-cols-7 gap-2 mb-6">
      {Array.from({ length: maxNumber }, (_, i) => i + 1).map((number) => (
        <button
          key={number}
          onClick={() => handleNumberSelect(number)}
          disabled={!selectedNumbers.includes(number) && selectedNumbers.length >= numbersToSelect}
          className={`
            w-10 h-10 rounded-lg border-2 font-semibold text-sm transition-all duration-200
            ${selectedNumbers.includes(number)
              ? 'bg-purple-500 border-purple-400 text-white shadow-lg shadow-purple-500/25'
              : 'bg-gray-800 border-gray-600 text-gray-300 hover:bg-gray-700 hover:border-gray-500'
            }
            ${!selectedNumbers.includes(number) && selectedNumbers.length >= numbersToSelect
              ? 'opacity-50 cursor-not-allowed'
              : 'cursor-pointer'
            }
          `}
        >
          {number}
        </button>
      ))}
    </div>
  );

  const BuyTicketsTab = () => (
    <div className="space-y-6">
      {/* Current Round Info */}
      <div className="bg-gradient-to-r from-purple-500/10 to-pink-500/10 rounded-xl p-6 border border-purple-500/20">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div className="text-center">
            <CalendarIcon className="h-8 w-8 text-purple-400 mx-auto mb-2" />
            <p className="text-gray-400 text-sm">Round #{currentRound.id}</p>
            <p className="text-white font-semibold">Weekly Draw</p>
          </div>
          <div className="text-center">
            <TrophyIcon className="h-8 w-8 text-yellow-400 mx-auto mb-2" />
            <p className="text-gray-400 text-sm">Prize Pool</p>
            <p className="text-white font-semibold">{currentRound.prizePool} GAME</p>
          </div>
          <div className="text-center">
            <ClockIcon className="h-8 w-8 text-blue-400 mx-auto mb-2" />
            <p className="text-gray-400 text-sm">Time Remaining</p>
            <p className="text-white font-semibold">{formatTimeRemaining(timeUntilDraw)}</p>
          </div>
        </div>
      </div>

      {/* Number Selection */}
      <div>
        <div className="flex justify-between items-center mb-4">
          <h3 className="text-lg font-semibold text-white">
            Select {numbersToSelect} Numbers (1-{maxNumber})
          </h3>
          <button
            onClick={handleQuickPick}
            className="px-4 py-2 bg-purple-600 hover:bg-purple-700 text-white rounded-lg font-medium transition-colors"
          >
            Quick Pick
          </button>
        </div>
        
        <NumberGrid />

        {selectedNumbers.length > 0 && (
          <div className="bg-gray-800/50 rounded-lg p-4 mb-4">
            <p className="text-gray-400 text-sm mb-2">Selected Numbers:</p>
            <div className="flex gap-2">
              {selectedNumbers.map((number) => (
                <span key={number} className="px-3 py-1 bg-purple-500 text-white rounded-lg font-semibold">
                  {number}
                </span>
              ))}
            </div>
          </div>
        )}
      </div>

      {/* Ticket Quantity */}
      <div>
        <h3 className="text-lg font-semibold text-white mb-4">Number of Tickets</h3>
        <div className="flex items-center gap-4">
          <button
            onClick={() => setTicketCount(Math.max(1, ticketCount - 1))}
            className="px-4 py-2 bg-gray-700 hover:bg-gray-600 text-white rounded-lg transition-colors"
          >
            -
          </button>
          <span className="text-2xl font-bold text-white w-16 text-center">{ticketCount}</span>
          <button
            onClick={() => setTicketCount(Math.min(10, ticketCount + 1))}
            className="px-4 py-2 bg-gray-700 hover:bg-gray-600 text-white rounded-lg transition-colors"
          >
            +
          </button>
          <div className="ml-auto">
            <p className="text-gray-400 text-sm">Total Cost</p>
            <p className="text-2xl font-bold text-white">{totalCost} GAME</p>
          </div>
        </div>
      </div>

      {/* Buy Button */}
      <button
        disabled={!canBuyTickets}
        className={`
          w-full py-4 rounded-xl font-semibold text-lg transition-all duration-200
          ${canBuyTickets
            ? 'bg-gradient-to-r from-purple-600 to-pink-600 hover:from-purple-700 hover:to-pink-700 text-white shadow-lg shadow-purple-500/25'
            : 'bg-gray-700 text-gray-400 cursor-not-allowed'
          }
        `}
      >
        {!isConnected 
          ? 'Connect Wallet' 
          : selectedNumbers.length < numbersToSelect
          ? `Select ${numbersToSelect - selectedNumbers.length} more number${numbersToSelect - selectedNumbers.length > 1 ? 's' : ''}`
          : `Buy ${ticketCount} Ticket${ticketCount > 1 ? 's' : ''} for ${totalCost} GAME`
        }
      </button>
    </div>
  );

  const HistoryTab = () => (
    <div className="space-y-4">
      <h3 className="text-lg font-semibold text-white mb-4">Your Tickets</h3>
      {userTickets.length > 0 ? (
        userTickets.map((ticket) => (
          <div key={ticket.ticketId} className="bg-gray-800/50 rounded-lg p-4 border border-gray-600/50">
            <div className="flex justify-between items-start mb-3">
              <div>
                <p className="text-white font-semibold">Ticket #{ticket.ticketId}</p>
                <p className="text-gray-400 text-sm">Round #{ticket.roundId}</p>
              </div>
              <div className="text-right">
                <p className="text-gray-400 text-sm">Purchased</p>
                <p className="text-white text-sm">{new Date(ticket.purchaseTime).toLocaleString()}</p>
              </div>
            </div>
            <div className="flex gap-2">
              {ticket.numbers.map((number) => (
                <span key={number} className="px-3 py-1 bg-purple-500/20 border border-purple-500/50 text-purple-300 rounded-lg font-semibold">
                  {number}
                </span>
              ))}
            </div>
          </div>
        ))
      ) : (
        <div className="text-center py-8">
          <TicketIcon className="h-16 w-16 text-gray-500 mx-auto mb-4" />
          <p className="text-gray-400">No tickets purchased yet</p>
        </div>
      )}
    </div>
  );

  const WinnersTab = () => (
    <div className="space-y-4">
      <h3 className="text-lg font-semibold text-white mb-4">Recent Winners</h3>
      {previousWinners.map((winner) => (
        <div key={winner.round} className="bg-gradient-to-r from-yellow-500/10 to-orange-500/10 rounded-lg p-4 border border-yellow-500/20">
          <div className="flex justify-between items-start mb-3">
            <div>
              <p className="text-white font-semibold">Round #{winner.round} Winner</p>
              <p className="text-gray-400 text-sm">{winner.address}</p>
            </div>
            <div className="text-right">
              <p className="text-yellow-400 font-semibold">{winner.prize}</p>
            </div>
          </div>
          <div className="flex gap-2">
            {winner.numbers.map((number) => (
              <span key={number} className="px-3 py-1 bg-yellow-500/20 border border-yellow-500/50 text-yellow-300 rounded-lg font-semibold">
                {number}
              </span>
            ))}
          </div>
        </div>
      ))}
    </div>
  );

  if (!isConnected) {
    return (
      <div className="text-center py-12">
        <SparklesIcon className="h-16 w-16 text-gray-500 mx-auto mb-4" />
        <h3 className="text-xl font-semibold text-gray-300 mb-2">Connect Wallet to Play Lottery</h3>
        <p className="text-gray-500">Connect your wallet to purchase lottery tickets and win big prizes.</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Stats Bar */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="bg-purple-500/10 rounded-xl p-4 border border-purple-500/20">
          <div className="flex items-center gap-3">
            <UserGroupIcon className="h-8 w-8 text-purple-400" />
            <div>
              <p className="text-gray-400 text-sm">Total Players</p>
              <p className="text-xl font-semibold text-white">{currentRound.totalTickets}</p>
            </div>
          </div>
        </div>
        
        <div className="bg-yellow-500/10 rounded-xl p-4 border border-yellow-500/20">
          <div className="flex items-center gap-3">
            <TrophyIcon className="h-8 w-8 text-yellow-400" />
            <div>
              <p className="text-gray-400 text-sm">Current Prize</p>
              <p className="text-xl font-semibold text-white">{currentRound.prizePool} GAME</p>
            </div>
          </div>
        </div>
        
        <div className="bg-blue-500/10 rounded-xl p-4 border border-blue-500/20">
          <div className="flex items-center gap-3">
            <TicketIcon className="h-8 w-8 text-blue-400" />
            <div>
              <p className="text-gray-400 text-sm">Ticket Price</p>
              <p className="text-xl font-semibold text-white">{ticketPrice} GAME</p>
            </div>
          </div>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex gap-2 mb-6">
        {[
          { id: 'buy', label: 'Buy Tickets', icon: TicketIcon },
          { id: 'history', label: 'My Tickets', icon: ClockIcon },
          { id: 'winners', label: 'Winners', icon: TrophyIcon }
        ].map((tab) => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id as any)}
            className={`
              flex items-center gap-2 px-4 py-2 rounded-lg font-medium transition-colors
              ${activeTab === tab.id
                ? 'bg-purple-600 text-white'
                : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
              }
            `}
          >
            <tab.icon className="h-5 w-5" />
            {tab.label}
          </button>
        ))}
      </div>

      {/* Tab Content */}
      {activeTab === 'buy' && <BuyTicketsTab />}
      {activeTab === 'history' && <HistoryTab />}
      {activeTab === 'winners' && <WinnersTab />}
    </div>
  );
}