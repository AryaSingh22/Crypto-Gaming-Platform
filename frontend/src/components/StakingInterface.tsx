'use client';

import React, { useState } from 'react';
import { 
  BanknotesIcon, 
  ClockIcon, 
  TrophyIcon, 
  ChartBarIcon,
  CurrencyDollarIcon,
  CalendarIcon,
  FireIcon,
  ArrowUpIcon,
  GiftIcon,
  LockClosedIcon
} from '@heroicons/react/24/outline';
import { useAccount, useBalance } from 'wagmi';

interface StakePosition {
  id: string;
  amount: string;
  lockPeriod: number;
  multiplier: number;
  startTime: number;
  endTime: number;
  rewards: string;
  status: 'active' | 'completed' | 'withdrawn';
}

interface LockPeriod {
  id: number;
  duration: number;
  multiplier: number;
  label: string;
  description: string;
  apy: number;
}

export default function StakingInterface() {
  const { address, isConnected } = useAccount();
  const { data: balance } = useBalance({
    address: address,
  });

  const [activeTab, setActiveTab] = useState<'stake' | 'positions' | 'rewards'>('stake');
  const [stakeAmount, setStakeAmount] = useState('');
  const [selectedLockPeriod, setSelectedLockPeriod] = useState(1);

  // Lock periods configuration
  const lockPeriods: LockPeriod[] = [
    {
      id: 0,
      duration: 0,
      multiplier: 0.8,
      label: 'Flexible',
      description: 'No lock period, withdraw anytime',
      apy: 12
    },
    {
      id: 1,
      duration: 30,
      multiplier: 1.0,
      label: '30 Days',
      description: 'Standard staking period',
      apy: 18
    },
    {
      id: 2,
      duration: 90,
      multiplier: 1.5,
      label: '90 Days',
      description: 'Enhanced rewards',
      apy: 28
    },
    {
      id: 3,
      duration: 180,
      multiplier: 2.0,
      label: '180 Days',
      description: 'High yield staking',
      apy: 42
    },
    {
      id: 4,
      duration: 365,
      multiplier: 3.0,
      label: '365 Days',
      description: 'Maximum rewards',
      apy: 65
    }
  ];

  // Mock user positions - replace with actual contract calls
  const userPositions: StakePosition[] = [
    {
      id: '1',
      amount: '1000',
      lockPeriod: 90,
      multiplier: 1.5,
      startTime: Date.now() - 45 * 24 * 60 * 60 * 1000, // 45 days ago
      endTime: Date.now() + 45 * 24 * 60 * 60 * 1000, // 45 days from now
      rewards: '125.50',
      status: 'active'
    },
    {
      id: '2',
      amount: '500',
      lockPeriod: 30,
      multiplier: 1.0,
      startTime: Date.now() - 35 * 24 * 60 * 60 * 1000, // 35 days ago
      endTime: Date.now() - 5 * 24 * 60 * 60 * 1000, // Completed 5 days ago
      rewards: '28.75',
      status: 'completed'
    }
  ];

  // Platform stats
  const platformStats = {
    totalStaked: '2,145,600',
    totalStakers: 1847,
    averageAPY: 32.5,
    totalRewardsDistributed: '145,280'
  };

  const selectedPeriod = lockPeriods.find(p => p.id === selectedLockPeriod) || lockPeriods[1];
  const estimatedRewards = stakeAmount ? (parseFloat(stakeAmount) * selectedPeriod.apy / 100 / 365 * selectedPeriod.duration).toFixed(2) : '0';

  const formatTimeRemaining = (ms: number) => {
    if (ms <= 0) return 'Completed';
    const days = Math.floor(ms / (1000 * 60 * 60 * 24));
    const hours = Math.floor((ms % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
    if (days > 0) return `${days}d ${hours}h`;
    return `${hours}h`;
  };

  const formatDuration = (days: number) => {
    if (days === 0) return 'Flexible';
    if (days < 30) return `${days} days`;
    if (days < 365) return `${Math.floor(days / 30)} months`;
    return `${Math.floor(days / 365)} year`;
  };

  const StakeTab = () => (
    <div className="max-w-4xl mx-auto space-y-8">
      {/* Platform Stats */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="bg-blue-500/10 rounded-xl p-4 border border-blue-500/20">
          <div className="flex items-center gap-3">
            <BanknotesIcon className="h-8 w-8 text-blue-400" />
            <div>
              <p className="text-gray-400 text-sm">Total Staked</p>
              <p className="text-xl font-semibold text-white">{platformStats.totalStaked} GAME</p>
            </div>
          </div>
        </div>
        
        <div className="bg-green-500/10 rounded-xl p-4 border border-green-500/20">
          <div className="flex items-center gap-3">
            <ChartBarIcon className="h-8 w-8 text-green-400" />
            <div>
              <p className="text-gray-400 text-sm">Avg APY</p>
              <p className="text-xl font-semibold text-white">{platformStats.averageAPY}%</p>
            </div>
          </div>
        </div>
        
        <div className="bg-purple-500/10 rounded-xl p-4 border border-purple-500/20">
          <div className="flex items-center gap-3">
            <TrophyIcon className="h-8 w-8 text-purple-400" />
            <div>
              <p className="text-gray-400 text-sm">Stakers</p>
              <p className="text-xl font-semibold text-white">{platformStats.totalStakers.toLocaleString()}</p>
            </div>
          </div>
        </div>
        
        <div className="bg-yellow-500/10 rounded-xl p-4 border border-yellow-500/20">
          <div className="flex items-center gap-3">
            <GiftIcon className="h-8 w-8 text-yellow-400" />
            <div>
              <p className="text-gray-400 text-sm">Rewards Paid</p>
              <p className="text-xl font-semibold text-white">{platformStats.totalRewardsDistributed} GAME</p>
            </div>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        {/* Staking Form */}
        <div className="space-y-6">
          <h3 className="text-xl font-semibold text-white">Stake GAME Tokens</h3>
          
          {/* Amount Input */}
          <div>
            <label className="block text-white font-medium mb-2">Amount to Stake</label>
            <div className="relative">
              <input
                type="number"
                value={stakeAmount}
                onChange={(e) => setStakeAmount(e.target.value)}
                placeholder="Enter amount"
                className="w-full px-4 py-3 bg-gray-800 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-blue-500"
              />
              <div className="absolute right-3 top-3 flex items-center gap-2">
                <span className="text-gray-400">GAME</span>
                <button
                  onClick={() => setStakeAmount(balance ? balance.formatted : '0')}
                  className="text-blue-400 hover:text-blue-300 text-sm font-medium"
                >
                  MAX
                </button>
              </div>
            </div>
            {balance && (
              <p className="text-gray-400 text-sm mt-1">
                Balance: {parseFloat(balance.formatted).toFixed(2)} GAME
              </p>
            )}
          </div>

          {/* Lock Period Selection */}
          <div>
            <label className="block text-white font-medium mb-3">Lock Period</label>
            <div className="space-y-2">
              {lockPeriods.map((period) => (
                <button
                  key={period.id}
                  onClick={() => setSelectedLockPeriod(period.id)}
                  className={`
                    w-full p-4 rounded-xl border-2 text-left transition-all
                    ${selectedLockPeriod === period.id
                      ? 'border-blue-500 bg-blue-500/10'
                      : 'border-gray-600 bg-gray-800/50 hover:border-gray-500'
                    }
                  `}
                >
                  <div className="flex justify-between items-center">
                    <div>
                      <div className="flex items-center gap-2 mb-1">
                        {period.duration === 0 ? (
                          <ArrowUpIcon className="h-4 w-4 text-green-400" />
                        ) : (
                          <LockClosedIcon className="h-4 w-4 text-blue-400" />
                        )}
                        <h4 className="text-white font-semibold">{period.label}</h4>
                      </div>
                      <p className="text-gray-400 text-sm">{period.description}</p>
                    </div>
                    <div className="text-right">
                      <p className="text-white font-semibold">{period.apy}% APY</p>
                      <p className="text-gray-400 text-sm">{period.multiplier}x multiplier</p>
                    </div>
                  </div>
                </button>
              ))}
            </div>
          </div>

          {/* Stake Button */}
          <button
            disabled={!stakeAmount || !isConnected || parseFloat(stakeAmount) <= 0}
            className={`
              w-full py-4 rounded-xl font-semibold text-lg transition-all
              ${stakeAmount && isConnected && parseFloat(stakeAmount) > 0
                ? 'bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-700 hover:to-purple-700 text-white'
                : 'bg-gray-700 text-gray-400 cursor-not-allowed'
              }
            `}
          >
            {!isConnected ? 'Connect Wallet' : 'Stake Tokens'}
          </button>
        </div>

        {/* Staking Summary */}
        <div className="bg-gray-800/50 rounded-xl p-6 border border-gray-600/50">
          <h3 className="text-xl font-semibold text-white mb-6">Staking Summary</h3>
          
          <div className="space-y-4">
            <div className="flex justify-between">
              <span className="text-gray-400">Stake Amount</span>
              <span className="text-white font-semibold">{stakeAmount || '0'} GAME</span>
            </div>
            
            <div className="flex justify-between">
              <span className="text-gray-400">Lock Period</span>
              <span className="text-white font-semibold">{formatDuration(selectedPeriod.duration)}</span>
            </div>
            
            <div className="flex justify-between">
              <span className="text-gray-400">APY</span>
              <span className="text-green-400 font-semibold">{selectedPeriod.apy}%</span>
            </div>
            
            <div className="flex justify-between">
              <span className="text-gray-400">Multiplier</span>
              <span className="text-blue-400 font-semibold">{selectedPeriod.multiplier}x</span>
            </div>
            
            <hr className="border-gray-700" />
            
            <div className="flex justify-between">
              <span className="text-gray-400">Estimated Rewards</span>
              <span className="text-yellow-400 font-semibold">+{estimatedRewards} GAME</span>
            </div>
            
            {selectedPeriod.duration > 0 && (
              <div className="flex justify-between">
                <span className="text-gray-400">Unlock Date</span>
                <span className="text-white font-semibold">
                  {new Date(Date.now() + selectedPeriod.duration * 24 * 60 * 60 * 1000).toLocaleDateString()}
                </span>
              </div>
            )}
          </div>

          {/* Benefits */}
          <div className="mt-6 p-4 bg-blue-500/10 rounded-lg border border-blue-500/20">
            <h4 className="text-blue-400 font-semibold mb-2">Staking Benefits</h4>
            <ul className="text-sm text-gray-300 space-y-1">
              <li>• Earn passive income on your GAME tokens</li>
              <li>• Higher multipliers for longer lock periods</li>
              <li>• Additional bonuses based on your NFT tier</li>
              <li>• Participate in platform governance (coming soon)</li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  );

  const PositionsTab = () => (
    <div className="space-y-6">
      <h3 className="text-lg font-semibold text-white">Your Staking Positions</h3>
      
      <div className="grid gap-4">
        {userPositions.map((position) => (
          <div key={position.id} className="bg-gray-800/50 rounded-xl p-6 border border-gray-600/50">
            <div className="flex justify-between items-start mb-4">
              <div>
                <h4 className="text-white font-semibold text-lg">{position.amount} GAME</h4>
                <p className="text-gray-400 text-sm">
                  {formatDuration(position.lockPeriod)} • {position.multiplier}x multiplier
                </p>
              </div>
              <div className="text-right">
                <div className={`
                  px-3 py-1 rounded-full text-sm font-medium
                  ${position.status === 'active' ? 'bg-green-500/20 text-green-400' :
                    position.status === 'completed' ? 'bg-blue-500/20 text-blue-400' :
                    'bg-gray-500/20 text-gray-400'
                  }
                `}>
                  {position.status}
                </div>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
              <div className="bg-gray-700/30 rounded-lg p-3">
                <p className="text-gray-400 text-sm">Staked Date</p>
                <p className="text-white font-semibold">
                  {new Date(position.startTime).toLocaleDateString()}
                </p>
              </div>
              
              <div className="bg-gray-700/30 rounded-lg p-3">
                <p className="text-gray-400 text-sm">
                  {position.status === 'active' ? 'Unlocks In' : 'Unlocked'}
                </p>
                <p className="text-white font-semibold">
                  {position.status === 'active' 
                    ? formatTimeRemaining(position.endTime - Date.now())
                    : new Date(position.endTime).toLocaleDateString()
                  }
                </p>
              </div>
              
              <div className="bg-yellow-500/10 rounded-lg p-3 border border-yellow-500/20">
                <p className="text-gray-400 text-sm">Earned Rewards</p>
                <p className="text-yellow-400 font-semibold">{position.rewards} GAME</p>
              </div>
            </div>

            <div className="flex gap-3">
              {position.status === 'active' && position.lockPeriod === 0 && (
                <button className="px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg font-medium transition-colors">
                  Unstake
                </button>
              )}
              
              {position.status === 'completed' && (
                <button className="px-4 py-2 bg-green-600 hover:bg-green-700 text-white rounded-lg font-medium transition-colors">
                  Withdraw
                </button>
              )}
              
              <button className="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-medium transition-colors">
                Claim Rewards
              </button>
            </div>
          </div>
        ))}
      </div>

      {userPositions.length === 0 && (
        <div className="text-center py-12">
          <BanknotesIcon className="h-16 w-16 text-gray-500 mx-auto mb-4" />
          <p className="text-gray-400 mb-4">You have no staking positions</p>
          <button
            onClick={() => setActiveTab('stake')}
            className="px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-medium transition-colors"
          >
            Start Staking
          </button>
        </div>
      )}
    </div>
  );

  const RewardsTab = () => {
    const totalEarned = userPositions.reduce((sum, pos) => sum + parseFloat(pos.rewards), 0);
    const claimableRewards = totalEarned.toFixed(2);

    return (
      <div className="space-y-6">
        <h3 className="text-lg font-semibold text-white">Rewards</h3>
        
        {/* Rewards Summary */}
        <div className="bg-gradient-to-r from-yellow-500/10 to-orange-500/10 rounded-xl p-6 border border-yellow-500/20">
          <div className="flex justify-between items-center">
            <div>
              <h4 className="text-2xl font-bold text-yellow-400">{claimableRewards} GAME</h4>
              <p className="text-gray-400">Total Claimable Rewards</p>
            </div>
            <button
              disabled={totalEarned === 0}
              className={`
                px-6 py-3 rounded-lg font-semibold transition-colors
                ${totalEarned > 0
                  ? 'bg-yellow-600 hover:bg-yellow-700 text-white'
                  : 'bg-gray-600 text-gray-400 cursor-not-allowed'
                }
              `}
            >
              Claim All Rewards
            </button>
          </div>
        </div>

        {/* Reward History */}
        <div className="bg-gray-800/50 rounded-xl p-6 border border-gray-600/50">
          <h4 className="text-lg font-semibold text-white mb-4">Reward History</h4>
          
          <div className="space-y-3">
            {/* Mock reward history */}
            {[
              { date: Date.now() - 1 * 24 * 60 * 60 * 1000, amount: '2.45', type: 'Daily Rewards' },
              { date: Date.now() - 2 * 24 * 60 * 60 * 1000, amount: '2.45', type: 'Daily Rewards' },
              { date: Date.now() - 3 * 24 * 60 * 60 * 1000, amount: '2.45', type: 'Daily Rewards' },
              { date: Date.now() - 7 * 24 * 60 * 60 * 1000, amount: '28.75', type: 'Position Completed' }
            ].map((reward, index) => (
              <div key={index} className="flex justify-between items-center py-3 border-b border-gray-700/50 last:border-b-0">
                <div>
                  <p className="text-white font-medium">{reward.type}</p>
                  <p className="text-gray-400 text-sm">{new Date(reward.date).toLocaleDateString()}</p>
                </div>
                <div className="text-right">
                  <p className="text-yellow-400 font-semibold">+{reward.amount} GAME</p>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Yield Calculator */}
        <div className="bg-gray-800/50 rounded-xl p-6 border border-gray-600/50">
          <h4 className="text-lg font-semibold text-white mb-4">Yield Calculator</h4>
          
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <label className="block text-gray-400 text-sm mb-2">Amount</label>
              <input
                type="number"
                placeholder="1000"
                className="w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm"
              />
            </div>
            
            <div>
              <label className="block text-gray-400 text-sm mb-2">Lock Period</label>
              <select className="w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm">
                {lockPeriods.map((period) => (
                  <option key={period.id} value={period.id}>{period.label}</option>
                ))}
              </select>
            </div>
            
            <div>
              <label className="block text-gray-400 text-sm mb-2">Estimated Yearly Yield</label>
              <div className="px-3 py-2 bg-green-500/10 border border-green-500/20 rounded-lg">
                <p className="text-green-400 font-semibold">+180 GAME</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  };

  if (!isConnected) {
    return (
      <div className="text-center py-12">
        <BanknotesIcon className="h-16 w-16 text-gray-500 mx-auto mb-4" />
        <h3 className="text-xl font-semibold text-gray-300 mb-2">Connect Wallet to Start Staking</h3>
        <p className="text-gray-500">Connect your wallet to stake GAME tokens and earn passive rewards.</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Tabs */}
      <div className="flex gap-2 mb-6">
        {[
          { id: 'stake', label: 'Stake', icon: BanknotesIcon },
          { id: 'positions', label: 'My Positions', icon: ClockIcon },
          { id: 'rewards', label: 'Rewards', icon: TrophyIcon }
        ].map((tab) => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id as any)}
            className={`
              flex items-center gap-2 px-4 py-2 rounded-lg font-medium transition-colors
              ${activeTab === tab.id
                ? 'bg-blue-600 text-white'
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
      {activeTab === 'stake' && <StakeTab />}
      {activeTab === 'positions' && <PositionsTab />}
      {activeTab === 'rewards' && <RewardsTab />}
    </div>
  );
}