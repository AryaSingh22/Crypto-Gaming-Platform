'use client';

import React, { useState } from 'react';
import { 
  TrophyIcon, 
  FireIcon, 
  CurrencyDollarIcon, 
  SparklesIcon,
  ChartBarIcon,
  ClockIcon,
  StarIcon,
  UserIcon,
  CalendarIcon,
  BanknotesIcon,
  GiftIcon,
  ShieldCheckIcon
} from '@heroicons/react/24/outline';
import { useAccount } from 'wagmi';

interface LeaderboardEntry {
  rank: number;
  address: string;
  displayName?: string;
  avatar?: string;
  score: string;
  tier: 'Bronze' | 'Silver' | 'Gold';
  change: number; // Position change from last period
  isCurrentUser?: boolean;
}

interface Achievement {
  id: string;
  name: string;
  description: string;
  icon: string;
  rarity: 'Common' | 'Rare' | 'Epic' | 'Legendary';
  unlockedAt?: number;
  progress?: {
    current: number;
    required: number;
  };
}

export default function Leaderboards() {
  const { address, isConnected } = useAccount();
  const [activeLeaderboard, setActiveLeaderboard] = useState<'overall' | 'coinflip' | 'lottery' | 'pvp' | 'staking' | 'referrals'>('overall');
  const [timeframe, setTimeframe] = useState<'daily' | 'weekly' | 'monthly' | 'all-time'>('weekly');
  const [activeTab, setActiveTab] = useState<'leaderboards' | 'achievements' | 'community'>('leaderboards');

  // Mock leaderboard data
  const leaderboardData: { [key: string]: LeaderboardEntry[] } = {
    overall: [
      { rank: 1, address: '0x1111...1111', displayName: 'CryptoKing', score: '125,450', tier: 'Gold', change: 0 },
      { rank: 2, address: '0x2222...2222', displayName: 'GameMaster', score: '98,720', tier: 'Gold', change: 1 },
      { rank: 3, address: '0x3333...3333', displayName: 'LuckyPlayer', score: '87,650', tier: 'Silver', change: -1 },
      { rank: 4, address: '0x4444...4444', score: '76,890', tier: 'Silver', change: 2 },
      { rank: 5, address: '0x5555...5555', score: '65,320', tier: 'Bronze', change: -1 },
      { rank: 25, address: address || '', score: '12,450', tier: 'Bronze', change: 3, isCurrentUser: true }
    ],
    coinflip: [
      { rank: 1, address: '0x1111...1111', displayName: 'FlipMaster', score: '89.5%', tier: 'Gold', change: 0 },
      { rank: 2, address: '0x2222...2222', score: '87.2%', tier: 'Gold', change: 1 },
      { rank: 3, address: '0x3333...3333', score: '85.1%', tier: 'Silver', change: -1 }
    ],
    lottery: [
      { rank: 1, address: '0x1111...1111', displayName: 'LotteryLuck', score: '45,000', tier: 'Gold', change: 0 },
      { rank: 2, address: '0x2222...2222', score: '38,500', tier: 'Silver', change: 2 },
      { rank: 3, address: '0x3333...3333', score: '32,100', tier: 'Silver', change: -1 }
    ]
  };

  const achievements: Achievement[] = [
    {
      id: '1',
      name: 'First Win',
      description: 'Win your first game',
      icon: '🎉',
      rarity: 'Common',
      unlockedAt: Date.now() - 5 * 24 * 60 * 60 * 1000
    },
    {
      id: '2',
      name: 'High Roller',
      description: 'Place a bet of 1000+ GAME',
      icon: '💎',
      rarity: 'Rare',
      unlockedAt: Date.now() - 3 * 24 * 60 * 60 * 1000
    },
    {
      id: '3',
      name: 'Lucky Streak',
      description: 'Win 10 games in a row',
      icon: '🔥',
      rarity: 'Epic',
      progress: { current: 7, required: 10 }
    },
    {
      id: '4',
      name: 'Lottery Winner',
      description: 'Win the weekly lottery',
      icon: '🎰',
      rarity: 'Legendary'
    },
    {
      id: '5',
      name: 'Community Leader',
      description: 'Refer 50+ users',
      icon: '👑',
      rarity: 'Epic',
      progress: { current: 12, required: 50 }
    }
  ];

  const communityStats = {
    totalPlayers: 15847,
    gamesPlayed: 234567,
    totalVolume: '2.1M',
    activePools: 8,
    weeklyActive: 3428
  };

  const leaderboardConfigs = [
    { id: 'overall', label: 'Overall', icon: TrophyIcon, metric: 'Experience Points' },
    { id: 'coinflip', label: 'CoinFlip', icon: CurrencyDollarIcon, metric: 'Win Rate' },
    { id: 'lottery', label: 'Lottery', icon: SparklesIcon, metric: 'Total Winnings' },
    { id: 'pvp', label: 'PvP', icon: FireIcon, metric: 'PvP Rating' },
    { id: 'staking', label: 'Staking', icon: BanknotesIcon, metric: 'Staked Amount' },
    { id: 'referrals', label: 'Referrals', icon: GiftIcon, metric: 'Referrals Made' }
  ];

  const getRankIcon = (rank: number) => {
    if (rank === 1) return '🥇';
    if (rank === 2) return '🥈';
    if (rank === 3) return '🥉';
    return `#${rank}`;
  };

  const getTierColor = (tier: string) => {
    switch (tier) {
      case 'Bronze': return 'text-orange-400';
      case 'Silver': return 'text-gray-400';
      case 'Gold': return 'text-yellow-400';
      default: return 'text-gray-400';
    }
  };

  const getTierBg = (tier: string) => {
    switch (tier) {
      case 'Bronze': return 'bg-orange-500/20 border-orange-500/50';
      case 'Silver': return 'bg-gray-500/20 border-gray-500/50';
      case 'Gold': return 'bg-yellow-500/20 border-yellow-500/50';
      default: return 'bg-gray-500/20 border-gray-500/50';
    }
  };

  const getRarityColor = (rarity: string) => {
    switch (rarity) {
      case 'Common': return 'text-gray-400 border-gray-500/50';
      case 'Rare': return 'text-blue-400 border-blue-500/50';
      case 'Epic': return 'text-purple-400 border-purple-500/50';
      case 'Legendary': return 'text-yellow-400 border-yellow-500/50';
      default: return 'text-gray-400 border-gray-500/50';
    }
  };

  const getChangeIndicator = (change: number) => {
    if (change > 0) return <span className="text-green-400 text-sm">↑{change}</span>;
    if (change < 0) return <span className="text-red-400 text-sm">↓{Math.abs(change)}</span>;
    return <span className="text-gray-400 text-sm">-</span>;
  };

  const LeaderboardsTab = () => (
    <div className="space-y-6">
      {/* Leaderboard Selection */}
      <div className="flex flex-wrap gap-2">
        {leaderboardConfigs.map((config) => (
          <button
            key={config.id}
            onClick={() => setActiveLeaderboard(config.id as any)}
            className={`
              flex items-center gap-2 px-4 py-2 rounded-lg font-medium transition-colors
              ${activeLeaderboard === config.id
                ? 'bg-blue-600 text-white'
                : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
              }
            `}
          >
            <config.icon className="h-5 w-5" />
            {config.label}
          </button>
        ))}
      </div>

      {/* Timeframe Selection */}
      <div className="flex gap-2">
        {[
          { id: 'daily', label: 'Daily' },
          { id: 'weekly', label: 'Weekly' },
          { id: 'monthly', label: 'Monthly' },
          { id: 'all-time', label: 'All Time' }
        ].map((period) => (
          <button
            key={period.id}
            onClick={() => setTimeframe(period.id as any)}
            className={`
              px-3 py-1 rounded-lg text-sm font-medium transition-colors
              ${timeframe === period.id
                ? 'bg-purple-600 text-white'
                : 'bg-gray-700 text-gray-300 hover:bg-gray-600'
              }
            `}
          >
            {period.label}
          </button>
        ))}
      </div>

      {/* Current Leaderboard */}
      <div className="bg-gray-800/50 rounded-xl border border-gray-600/50">
        <div className="p-6 border-b border-gray-700">
          <div className="flex items-center justify-between">
            <h3 className="text-xl font-semibold text-white">
              {leaderboardConfigs.find(c => c.id === activeLeaderboard)?.label} Leaderboard
            </h3>
            <div className="text-gray-400 text-sm">
              {leaderboardConfigs.find(c => c.id === activeLeaderboard)?.metric} • {timeframe}
            </div>
          </div>
        </div>

        <div className="divide-y divide-gray-700/50">
          {(leaderboardData[activeLeaderboard] || []).map((entry) => (
            <div 
              key={entry.rank}
              className={`
                p-4 hover:bg-gray-700/30 transition-colors
                ${entry.isCurrentUser ? 'bg-blue-500/10 border-l-4 border-blue-500' : ''}
              `}
            >
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-4">
                  <div className="text-2xl font-bold text-white w-12 text-center">
                    {getRankIcon(entry.rank)}
                  </div>
                  
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 bg-gradient-to-br from-blue-500 to-purple-500 rounded-full flex items-center justify-center">
                      <UserIcon className="h-5 w-5 text-white" />
                    </div>
                    <div>
                      <p className="text-white font-semibold">
                        {entry.isCurrentUser ? 'You' : (entry.displayName || `${entry.address.slice(0, 6)}...${entry.address.slice(-4)}`)}
                      </p>
                      <div className="flex items-center gap-2">
                        <span className={`px-2 py-1 rounded text-xs font-medium border ${getTierBg(entry.tier)}`}>
                          {entry.tier}
                        </span>
                        {getChangeIndicator(entry.change)}
                      </div>
                    </div>
                  </div>
                </div>

                <div className="text-right">
                  <p className="text-xl font-bold text-white">{entry.score}</p>
                  <p className="text-gray-400 text-sm">
                    {leaderboardConfigs.find(c => c.id === activeLeaderboard)?.metric}
                  </p>
                </div>
              </div>
            </div>
          ))}
        </div>

        {/* User's Position (if not in top) */}
        {activeLeaderboard === 'overall' && (leaderboardData[activeLeaderboard]?.find(e => e.isCurrentUser)?.rank || 0) > 10 && (
          <div className="p-4 border-t border-gray-700 bg-blue-500/10">
            <p className="text-center text-gray-400 text-sm mb-2">Your Position</p>
            {/* Show user's actual position */}
          </div>
        )}
      </div>
    </div>
  );

  const AchievementsTab = () => (
    <div className="space-y-6">
      <h3 className="text-xl font-semibold text-white">Achievements & Badges</h3>
      
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {achievements.map((achievement) => (
          <div 
            key={achievement.id}
            className={`
              p-6 rounded-xl border-2 transition-all
              ${achievement.unlockedAt 
                ? `bg-gradient-to-br from-green-500/10 to-blue-500/10 border-green-500/30` 
                : `bg-gray-800/50 border-gray-600/50 ${getRarityColor(achievement.rarity)}`
              }
            `}
          >
            <div className="text-center">
              <div className="text-4xl mb-3">{achievement.icon}</div>
              <h4 className="text-white font-semibold mb-2">{achievement.name}</h4>
              <p className="text-gray-400 text-sm mb-3">{achievement.description}</p>
              
              <div className="flex items-center justify-center gap-2 mb-3">
                <span className={`px-2 py-1 rounded text-xs font-medium ${getRarityColor(achievement.rarity)}`}>
                  {achievement.rarity}
                </span>
                {achievement.unlockedAt && (
                  <ShieldCheckIcon className="h-4 w-4 text-green-400" />
                )}
              </div>

              {achievement.progress && !achievement.unlockedAt && (
                <div>
                  <div className="w-full bg-gray-700 rounded-full h-2 mb-2">
                    <div 
                      className="bg-blue-500 h-2 rounded-full transition-all duration-500"
                      style={{ width: `${(achievement.progress.current / achievement.progress.required) * 100}%` }}
                    ></div>
                  </div>
                  <p className="text-xs text-gray-400">
                    {achievement.progress.current}/{achievement.progress.required}
                  </p>
                </div>
              )}

              {achievement.unlockedAt && (
                <p className="text-green-400 text-xs">
                  Unlocked {new Date(achievement.unlockedAt).toLocaleDateString()}
                </p>
              )}
            </div>
          </div>
        ))}
      </div>

      {/* Achievement Categories */}
      <div className="bg-gray-800/50 rounded-xl p-6 border border-gray-600/50">
        <h4 className="text-lg font-semibold text-white mb-4">Achievement Categories</h4>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {[
            { name: 'Gaming', count: 12, unlocked: 5, icon: '🎮' },
            { name: 'Social', count: 8, unlocked: 3, icon: '👥' },
            { name: 'Financial', count: 10, unlocked: 4, icon: '💰' },
            { name: 'Special', count: 5, unlocked: 1, icon: '⭐' }
          ].map((category) => (
            <div key={category.name} className="flex items-center justify-between p-4 bg-gray-700/30 rounded-lg">
              <div className="flex items-center gap-3">
                <span className="text-2xl">{category.icon}</span>
                <div>
                  <p className="text-white font-medium">{category.name}</p>
                  <p className="text-gray-400 text-sm">{category.unlocked}/{category.count} unlocked</p>
                </div>
              </div>
              <div className="w-16 h-2 bg-gray-600 rounded-full">
                <div 
                  className="h-2 bg-blue-500 rounded-full"
                  style={{ width: `${(category.unlocked / category.count) * 100}%` }}
                ></div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );

  const CommunityTab = () => (
    <div className="space-y-6">
      {/* Community Stats */}
      <div className="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-5 gap-4">
        <div className="bg-blue-500/10 rounded-xl p-4 border border-blue-500/20">
          <div className="text-center">
            <UserIcon className="h-8 w-8 text-blue-400 mx-auto mb-2" />
            <p className="text-2xl font-bold text-white">{communityStats.totalPlayers.toLocaleString()}</p>
            <p className="text-gray-400 text-sm">Total Players</p>
          </div>
        </div>

        <div className="bg-green-500/10 rounded-xl p-4 border border-green-500/20">
          <div className="text-center">
            <FireIcon className="h-8 w-8 text-green-400 mx-auto mb-2" />
            <p className="text-2xl font-bold text-white">{communityStats.gamesPlayed.toLocaleString()}</p>
            <p className="text-gray-400 text-sm">Games Played</p>
          </div>
        </div>

        <div className="bg-yellow-500/10 rounded-xl p-4 border border-yellow-500/20">
          <div className="text-center">
            <CurrencyDollarIcon className="h-8 w-8 text-yellow-400 mx-auto mb-2" />
            <p className="text-2xl font-bold text-white">{communityStats.totalVolume}</p>
            <p className="text-gray-400 text-sm">Total Volume</p>
          </div>
        </div>

        <div className="bg-purple-500/10 rounded-xl p-4 border border-purple-500/20">
          <div className="text-center">
            <ChartBarIcon className="h-8 w-8 text-purple-400 mx-auto mb-2" />
            <p className="text-2xl font-bold text-white">{communityStats.activePools}</p>
            <p className="text-gray-400 text-sm">Active Pools</p>
          </div>
        </div>

        <div className="bg-red-500/10 rounded-xl p-4 border border-red-500/20">
          <div className="text-center">
            <ClockIcon className="h-8 w-8 text-red-400 mx-auto mb-2" />
            <p className="text-2xl font-bold text-white">{communityStats.weeklyActive.toLocaleString()}</p>
            <p className="text-gray-400 text-sm">Weekly Active</p>
          </div>
        </div>
      </div>

      {/* Recent Activity Feed */}
      <div className="bg-gray-800/50 rounded-xl border border-gray-600/50">
        <div className="p-6 border-b border-gray-700">
          <h3 className="text-lg font-semibold text-white">Community Activity</h3>
        </div>
        
        <div className="divide-y divide-gray-700/50">
          {[
            { user: 'CryptoKing', action: 'won the weekly lottery', amount: '45,000 GAME', time: '2 hours ago', type: 'lottery' },
            { user: 'GameMaster', action: 'achieved Gold tier', time: '4 hours ago', type: 'achievement' },
            { user: 'LuckyPlayer', action: 'won a PvP bet', amount: '500 GAME', time: '6 hours ago', type: 'pvp' },
            { user: 'FlipMaster', action: 'placed a high roller bet', amount: '2,000 GAME', time: '8 hours ago', type: 'coinflip' },
            { user: 'StakeKing', action: 'staked tokens for 365 days', amount: '10,000 GAME', time: '12 hours ago', type: 'staking' }
          ].map((activity, index) => (
            <div key={index} className="p-4 hover:bg-gray-700/30 transition-colors">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <div className="w-8 h-8 bg-gradient-to-br from-blue-500 to-purple-500 rounded-full flex items-center justify-center">
                    <UserIcon className="h-4 w-4 text-white" />
                  </div>
                  <div>
                    <p className="text-white">
                      <span className="font-semibold">{activity.user}</span> {activity.action}
                      {activity.amount && <span className="text-green-400 ml-1">for {activity.amount}</span>}
                    </p>
                    <p className="text-gray-400 text-sm">{activity.time}</p>
                  </div>
                </div>
                <div className={`
                  px-2 py-1 rounded text-xs font-medium
                  ${activity.type === 'lottery' ? 'bg-purple-500/20 text-purple-400' :
                    activity.type === 'achievement' ? 'bg-yellow-500/20 text-yellow-400' :
                    activity.type === 'pvp' ? 'bg-red-500/20 text-red-400' :
                    activity.type === 'coinflip' ? 'bg-green-500/20 text-green-400' :
                    'bg-blue-500/20 text-blue-400'
                  }
                `}>
                  {activity.type}
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Community Events */}
      <div className="bg-gradient-to-r from-purple-500/10 to-pink-500/10 rounded-xl p-6 border border-purple-500/20">
        <h3 className="text-lg font-semibold text-white mb-4">Upcoming Events</h3>
        <div className="space-y-3">
          {[
            { name: 'Weekly Tournament', date: 'This Weekend', prize: '50,000 GAME', participants: 234 },
            { name: 'Community Challenge', date: 'Next Week', prize: 'Exclusive NFT', participants: 89 },
            { name: 'Staking Rewards 2x', date: '3 Days', prize: 'Double APY', participants: 456 }
          ].map((event, index) => (
            <div key={index} className="flex items-center justify-between p-3 bg-gray-800/30 rounded-lg">
              <div>
                <p className="text-white font-medium">{event.name}</p>
                <p className="text-gray-400 text-sm">{event.participants} participants</p>
              </div>
              <div className="text-right">
                <p className="text-purple-400 font-semibold">{event.prize}</p>
                <p className="text-gray-400 text-sm">{event.date}</p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );

  if (!isConnected) {
    return (
      <div className="text-center py-12">
        <TrophyIcon className="h-16 w-16 text-gray-500 mx-auto mb-4" />
        <h3 className="text-xl font-semibold text-gray-300 mb-2">Connect Wallet to View Leaderboards</h3>
        <p className="text-gray-500">Connect your wallet to see rankings, achievements, and community features.</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Tabs */}
      <div className="flex gap-2 mb-6">
        {[
          { id: 'leaderboards', label: 'Leaderboards', icon: TrophyIcon },
          { id: 'achievements', label: 'Achievements', icon: StarIcon },
          { id: 'community', label: 'Community', icon: UserIcon }
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
      {activeTab === 'leaderboards' && <LeaderboardsTab />}
      {activeTab === 'achievements' && <AchievementsTab />}
      {activeTab === 'community' && <CommunityTab />}
    </div>
  );
}