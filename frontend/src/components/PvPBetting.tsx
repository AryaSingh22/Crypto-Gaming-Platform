'use client';

import React, { useState } from 'react';
import { 
  FireIcon, 
  UserGroupIcon, 
  ClockIcon, 
  TrophyIcon,
  CurrencyDollarIcon,
  ExclamationTriangleIcon,
  CheckCircleIcon,
  XCircleIcon,
  PlayIcon
} from '@heroicons/react/24/outline';
import { useAccount } from 'wagmi';

interface PvPBet {
  id: string;
  creator: string;
  opponent?: string;
  betType: 'coinflip' | 'skill' | 'custom';
  amount: string;
  description: string;
  status: 'open' | 'active' | 'disputed' | 'completed' | 'expired';
  createdAt: number;
  expiresAt: number;
  winner?: string;
}

interface BetResult {
  betId: string;
  player: string;
  result: 'win' | 'loss';
  evidence?: string;
}

export default function PvPBetting() {
  const { address, isConnected } = useAccount();
  const [activeTab, setActiveTab] = useState<'browse' | 'create' | 'my-bets' | 'disputes'>('browse');
  const [newBet, setNewBet] = useState({
    type: 'coinflip' as 'coinflip' | 'skill' | 'custom',
    amount: '',
    description: '',
    duration: '24'
  });

  // Mock data - replace with actual contract calls
  const openBets: PvPBet[] = [
    {
      id: '1',
      creator: '0x1234...5678',
      betType: 'coinflip',
      amount: '100',
      description: 'Simple coin flip bet - 50/50 odds',
      status: 'open',
      createdAt: Date.now() - 2 * 60 * 60 * 1000,
      expiresAt: Date.now() + 22 * 60 * 60 * 1000
    },
    {
      id: '2',
      creator: '0x2345...6789',
      betType: 'skill',
      amount: '250',
      description: 'Chess match - best of 3 games',
      status: 'open',
      createdAt: Date.now() - 1 * 60 * 60 * 1000,
      expiresAt: Date.now() + 23 * 60 * 60 * 1000
    },
    {
      id: '3',
      creator: '0x3456...7890',
      betType: 'custom',
      amount: '500',
      description: 'Who can get higher score in Snake game',
      status: 'open',
      createdAt: Date.now() - 30 * 60 * 1000,
      expiresAt: Date.now() + 23.5 * 60 * 60 * 1000
    }
  ];

  const myBets: PvPBet[] = [
    {
      id: '4',
      creator: address || '',
      opponent: '0x4567...8901',
      betType: 'coinflip',
      amount: '150',
      description: 'My coin flip challenge',
      status: 'active',
      createdAt: Date.now() - 4 * 60 * 60 * 1000,
      expiresAt: Date.now() + 20 * 60 * 60 * 1000
    },
    {
      id: '5',
      creator: '0x5678...9012',
      opponent: address || '',
      betType: 'skill',
      amount: '200',
      description: 'Rock Paper Scissors - best of 5',
      status: 'completed',
      createdAt: Date.now() - 2 * 24 * 60 * 60 * 1000,
      expiresAt: Date.now() - 1 * 24 * 60 * 60 * 1000,
      winner: address
    }
  ];

  const disputedBets: PvPBet[] = [
    {
      id: '6',
      creator: '0x6789...0123',
      opponent: address || '',
      betType: 'custom',
      amount: '300',
      description: 'Disputed game result',
      status: 'disputed',
      createdAt: Date.now() - 6 * 60 * 60 * 1000,
      expiresAt: Date.now() + 18 * 60 * 60 * 1000
    }
  ];

  const formatTimeRemaining = (ms: number) => {
    if (ms <= 0) return 'Expired';
    const hours = Math.floor(ms / (1000 * 60 * 60));
    const minutes = Math.floor((ms % (1000 * 60 * 60)) / (1000 * 60));
    if (hours > 0) return `${hours}h ${minutes}m`;
    return `${minutes}m`;
  };

  const getBetTypeIcon = (type: string) => {
    switch (type) {
      case 'coinflip':
        return <CurrencyDollarIcon className="h-5 w-5" />;
      case 'skill':
        return <TrophyIcon className="h-5 w-5" />;
      case 'custom':
        return <PlayIcon className="h-5 w-5" />;
      default:
        return <FireIcon className="h-5 w-5" />;
    }
  };

  const getBetTypeColor = (type: string) => {
    switch (type) {
      case 'coinflip':
        return 'text-green-400 bg-green-500/20 border-green-500/50';
      case 'skill':
        return 'text-blue-400 bg-blue-500/20 border-blue-500/50';
      case 'custom':
        return 'text-purple-400 bg-purple-500/20 border-purple-500/50';
      default:
        return 'text-gray-400 bg-gray-500/20 border-gray-500/50';
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'open':
        return 'text-blue-400';
      case 'active':
        return 'text-yellow-400';
      case 'completed':
        return 'text-green-400';
      case 'disputed':
        return 'text-red-400';
      case 'expired':
        return 'text-gray-400';
      default:
        return 'text-gray-400';
    }
  };

  const BrowseBetsTab = () => (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <h3 className="text-lg font-semibold text-white">Open Bets</h3>
        <div className="flex gap-2">
          <select className="px-3 py-1 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm">
            <option value="all">All Types</option>
            <option value="coinflip">Coin Flip</option>
            <option value="skill">Skill-based</option>
            <option value="custom">Custom</option>
          </select>
          <select className="px-3 py-1 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm">
            <option value="amount">Sort by Amount</option>
            <option value="time">Sort by Time</option>
          </select>
        </div>
      </div>

      {openBets.map((bet) => (
        <div key={bet.id} className="bg-gray-800/50 rounded-xl p-6 border border-gray-600/50 hover:border-gray-500/50 transition-all">
          <div className="flex justify-between items-start mb-4">
            <div className="flex items-center gap-3">
              <div className={`p-2 rounded-lg border ${getBetTypeColor(bet.betType)}`}>
                {getBetTypeIcon(bet.betType)}
              </div>
              <div>
                <h4 className="text-white font-semibold capitalize">{bet.betType} Bet</h4>
                <p className="text-gray-400 text-sm">by {bet.creator.slice(0, 6)}...{bet.creator.slice(-4)}</p>
              </div>
            </div>
            <div className="text-right">
              <p className="text-2xl font-bold text-white">{bet.amount} GAME</p>
              <p className={`text-sm ${getStatusColor(bet.status)}`}>
                {formatTimeRemaining(bet.expiresAt - Date.now())} left
              </p>
            </div>
          </div>

          <p className="text-gray-300 mb-4">{bet.description}</p>

          <div className="flex justify-between items-center">
            <div className="flex items-center gap-4 text-sm text-gray-400">
              <span className="flex items-center gap-1">
                <ClockIcon className="h-4 w-4" />
                {new Date(bet.createdAt).toLocaleDateString()}
              </span>
            </div>
            <button
              disabled={bet.creator === address}
              className={`
                px-6 py-2 rounded-lg font-medium transition-colors
                ${bet.creator === address
                  ? 'bg-gray-600 text-gray-400 cursor-not-allowed'
                  : 'bg-red-600 hover:bg-red-700 text-white'
                }
              `}
            >
              {bet.creator === address ? 'Your Bet' : 'Accept Challenge'}
            </button>
          </div>
        </div>
      ))}
    </div>
  );

  const CreateBetTab = () => (
    <div className="max-w-2xl mx-auto space-y-6">
      <h3 className="text-lg font-semibold text-white text-center">Create New Bet</h3>

      {/* Bet Type Selection */}
      <div>
        <label className="block text-white font-medium mb-3">Bet Type</label>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
          {[
            { type: 'coinflip', label: 'Coin Flip', desc: 'Pure luck, VRF powered' },
            { type: 'skill', label: 'Skill-based', desc: 'Requires manual result submission' },
            { type: 'custom', label: 'Custom', desc: 'Define your own challenge' }
          ].map((option) => (
            <button
              key={option.type}
              onClick={() => setNewBet({ ...newBet, type: option.type as any })}
              className={`
                p-4 rounded-xl border-2 text-left transition-all
                ${newBet.type === option.type
                  ? 'border-red-500 bg-red-500/10'
                  : 'border-gray-600 bg-gray-800/50 hover:border-gray-500'
                }
              `}
            >
              <div className="flex items-center gap-2 mb-2">
                {getBetTypeIcon(option.type)}
                <h4 className="text-white font-semibold">{option.label}</h4>
              </div>
              <p className="text-gray-400 text-sm">{option.desc}</p>
            </button>
          ))}
        </div>
      </div>

      {/* Bet Amount */}
      <div>
        <label className="block text-white font-medium mb-2">Bet Amount</label>
        <div className="relative">
          <input
            type="number"
            value={newBet.amount}
            onChange={(e) => setNewBet({ ...newBet, amount: e.target.value })}
            placeholder="Enter amount"
            className="w-full px-4 py-3 bg-gray-800 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-red-500"
          />
          <span className="absolute right-3 top-3 text-gray-400">GAME</span>
        </div>
      </div>

      {/* Description */}
      <div>
        <label className="block text-white font-medium mb-2">Description</label>
        <textarea
          value={newBet.description}
          onChange={(e) => setNewBet({ ...newBet, description: e.target.value })}
          placeholder="Describe your bet challenge..."
          rows={3}
          className="w-full px-4 py-3 bg-gray-800 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-red-500 resize-none"
        />
      </div>

      {/* Duration */}
      <div>
        <label className="block text-white font-medium mb-2">Duration</label>
        <select
          value={newBet.duration}
          onChange={(e) => setNewBet({ ...newBet, duration: e.target.value })}
          className="w-full px-4 py-3 bg-gray-800 border border-gray-600 rounded-lg text-white focus:outline-none focus:border-red-500"
        >
          <option value="1">1 Hour</option>
          <option value="6">6 Hours</option>
          <option value="24">24 Hours</option>
          <option value="72">3 Days</option>
          <option value="168">1 Week</option>
        </select>
      </div>

      {/* Create Button */}
      <button
        disabled={!newBet.amount || !newBet.description || !isConnected}
        className={`
          w-full py-4 rounded-xl font-semibold text-lg transition-all
          ${newBet.amount && newBet.description && isConnected
            ? 'bg-gradient-to-r from-red-600 to-orange-600 hover:from-red-700 hover:to-orange-700 text-white'
            : 'bg-gray-700 text-gray-400 cursor-not-allowed'
          }
        `}
      >
        Create Bet
      </button>
    </div>
  );

  const MyBetsTab = () => (
    <div className="space-y-4">
      <h3 className="text-lg font-semibold text-white">My Bets</h3>
      
      {myBets.map((bet) => (
        <div key={bet.id} className="bg-gray-800/50 rounded-xl p-6 border border-gray-600/50">
          <div className="flex justify-between items-start mb-4">
            <div className="flex items-center gap-3">
              <div className={`p-2 rounded-lg border ${getBetTypeColor(bet.betType)}`}>
                {getBetTypeIcon(bet.betType)}
              </div>
              <div>
                <h4 className="text-white font-semibold capitalize">{bet.betType} Bet</h4>
                <p className="text-gray-400 text-sm">
                  {bet.creator === address ? 'Created by you' : `vs ${bet.creator.slice(0, 6)}...${bet.creator.slice(-4)}`}
                </p>
              </div>
            </div>
            <div className="text-right">
              <p className="text-2xl font-bold text-white">{bet.amount} GAME</p>
              <p className={`text-sm ${getStatusColor(bet.status)}`}>
                {bet.status}
              </p>
            </div>
          </div>

          <p className="text-gray-300 mb-4">{bet.description}</p>

          <div className="flex justify-between items-center">
            <div className="flex items-center gap-4 text-sm text-gray-400">
              {bet.opponent && (
                <span>vs {bet.opponent.slice(0, 6)}...{bet.opponent.slice(-4)}</span>
              )}
              {bet.winner && (
                <span className="flex items-center gap-1 text-green-400">
                  <CheckCircleIcon className="h-4 w-4" />
                  {bet.winner === address ? 'You won!' : 'You lost'}
                </span>
              )}
            </div>
            
            {bet.status === 'active' && (
              <div className="flex gap-2">
                <button className="px-4 py-2 bg-green-600 hover:bg-green-700 text-white rounded-lg font-medium transition-colors">
                  Submit Result
                </button>
                <button className="px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg font-medium transition-colors">
                  Dispute
                </button>
              </div>
            )}
          </div>
        </div>
      ))}
    </div>
  );

  const DisputesTab = () => (
    <div className="space-y-4">
      <h3 className="text-lg font-semibold text-white">Disputed Bets</h3>
      
      {disputedBets.map((bet) => (
        <div key={bet.id} className="bg-red-500/10 rounded-xl p-6 border border-red-500/30">
          <div className="flex justify-between items-start mb-4">
            <div className="flex items-center gap-3">
              <ExclamationTriangleIcon className="h-8 w-8 text-red-400" />
              <div>
                <h4 className="text-white font-semibold">Disputed Bet</h4>
                <p className="text-gray-400 text-sm">Requires resolution</p>
              </div>
            </div>
            <div className="text-right">
              <p className="text-2xl font-bold text-white">{bet.amount} GAME</p>
              <p className="text-red-400 text-sm">Under Review</p>
            </div>
          </div>

          <p className="text-gray-300 mb-4">{bet.description}</p>

          <div className="bg-red-500/10 rounded-lg p-4 mb-4">
            <p className="text-red-300 text-sm">
              This bet is under dispute resolution. Both parties have submitted conflicting results.
              Our dispute resolution system will review the evidence and make a final decision.
            </p>
          </div>

          <div className="flex justify-between items-center">
            <div className="text-sm text-gray-400">
              Escalated {formatTimeRemaining(Date.now() - bet.createdAt)} ago
            </div>
            <button className="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-medium transition-colors">
              View Details
            </button>
          </div>
        </div>
      ))}
    </div>
  );

  if (!isConnected) {
    return (
      <div className="text-center py-12">
        <FireIcon className="h-16 w-16 text-gray-500 mx-auto mb-4" />
        <h3 className="text-xl font-semibold text-gray-300 mb-2">Connect Wallet for PvP Betting</h3>
        <p className="text-gray-500">Connect your wallet to create and accept peer-to-peer betting challenges.</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Stats */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="bg-red-500/10 rounded-xl p-4 border border-red-500/20">
          <div className="flex items-center gap-3">
            <FireIcon className="h-8 w-8 text-red-400" />
            <div>
              <p className="text-gray-400 text-sm">Open Bets</p>
              <p className="text-xl font-semibold text-white">{openBets.length}</p>
            </div>
          </div>
        </div>
        
        <div className="bg-blue-500/10 rounded-xl p-4 border border-blue-500/20">
          <div className="flex items-center gap-3">
            <UserGroupIcon className="h-8 w-8 text-blue-400" />
            <div>
              <p className="text-gray-400 text-sm">Active Players</p>
              <p className="text-xl font-semibold text-white">156</p>
            </div>
          </div>
        </div>
        
        <div className="bg-green-500/10 rounded-xl p-4 border border-green-500/20">
          <div className="flex items-center gap-3">
            <CurrencyDollarIcon className="h-8 w-8 text-green-400" />
            <div>
              <p className="text-gray-400 text-sm">Total Volume</p>
              <p className="text-xl font-semibold text-white">45.2K GAME</p>
            </div>
          </div>
        </div>
        
        <div className="bg-yellow-500/10 rounded-xl p-4 border border-yellow-500/20">
          <div className="flex items-center gap-3">
            <TrophyIcon className="h-8 w-8 text-yellow-400" />
            <div>
              <p className="text-gray-400 text-sm">Your Win Rate</p>
              <p className="text-xl font-semibold text-white">73.5%</p>
            </div>
          </div>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex gap-2 mb-6">
        {[
          { id: 'browse', label: 'Browse Bets', icon: FireIcon },
          { id: 'create', label: 'Create Bet', icon: PlayIcon },
          { id: 'my-bets', label: 'My Bets', icon: UserGroupIcon },
          { id: 'disputes', label: 'Disputes', icon: ExclamationTriangleIcon }
        ].map((tab) => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id as any)}
            className={`
              flex items-center gap-2 px-4 py-2 rounded-lg font-medium transition-colors
              ${activeTab === tab.id
                ? 'bg-red-600 text-white'
                : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
              }
            `}
          >
            <tab.icon className="h-5 w-5" />
            {tab.label}
            {tab.id === 'disputes' && disputedBets.length > 0 && (
              <span className="bg-red-500 text-white text-xs px-2 py-1 rounded-full">
                {disputedBets.length}
              </span>
            )}
          </button>
        ))}
      </div>

      {/* Tab Content */}
      {activeTab === 'browse' && <BrowseBetsTab />}
      {activeTab === 'create' && <CreateBetTab />}
      {activeTab === 'my-bets' && <MyBetsTab />}
      {activeTab === 'disputes' && <DisputesTab />}
    </div>
  );
}