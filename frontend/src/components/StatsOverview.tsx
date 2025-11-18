'use client';

import React from 'react';
import { 
  ChartBarIcon, 
  CurrencyDollarIcon, 
  SparklesIcon, 
  TrophyIcon,
  ArrowUpIcon,
  ArrowDownIcon,
  FireIcon,
  ClockIcon
} from '@heroicons/react/24/outline';
import { useAccount, useBalance } from 'wagmi';

interface StatCard {
  title: string;
  value: string;
  change: string;
  changeType: 'positive' | 'negative' | 'neutral';
  icon: React.ComponentType<{ className?: string }>;
  color: string;
}

interface RecentActivity {
  id: string;
  type: 'coinflip' | 'lottery' | 'pvp' | 'marketplace' | 'staking';
  description: string;
  amount: string;
  timestamp: string;
  status: 'win' | 'loss' | 'pending' | 'completed';
}

export default function StatsOverview() {
  const { address, isConnected } = useAccount();
  const { data: balance } = useBalance({
    address: address,
  });

  const platformStats: StatCard[] = [
    {
      title: 'Total Volume',
      value: '$2,157,432',
      change: '+12.5%',
      changeType: 'positive',
      icon: ChartBarIcon,
      color: 'blue'
    },
    {
      title: 'Active Games',
      value: '1,234',
      change: '+8.2%',
      changeType: 'positive',
      icon: FireIcon,
      color: 'red'
    },
    {
      title: 'Prize Pool',
      value: '450,000 GAME',
      change: '+5.7%',
      changeType: 'positive',
      icon: CurrencyDollarIcon,
      color: 'green'
    },
    {
      title: 'NFT Holders',
      value: '892',
      change: '+15.3%',
      changeType: 'positive',
      icon: SparklesIcon,
      color: 'purple'
    }
  ];

  const userStats: StatCard[] = [
    {
      title: 'GAME Balance',
      value: isConnected ? (balance ? `${parseFloat(balance.formatted).toFixed(2)} ${balance.symbol}` : '0.00') : '0.00 GAME',
      change: '+2.1%',
      changeType: 'positive',
      icon: CurrencyDollarIcon,
      color: 'green'
    },
    {
      title: 'Total Winnings',
      value: '1,250 GAME',
      change: '+24.5%',
      changeType: 'positive',
      icon: TrophyIcon,
      color: 'yellow'
    },
    {
      title: 'Games Played',
      value: '47',
      change: '+3',
      changeType: 'positive',
      icon: FireIcon,
      color: 'red'
    },
    {
      title: 'Win Rate',
      value: '68.1%',
      change: '+4.2%',
      changeType: 'positive',
      icon: ChartBarIcon,
      color: 'blue'
    }
  ];

  const recentActivity: RecentActivity[] = [
    {
      id: '1',
      type: 'coinflip',
      description: 'Won CoinFlip bet (Heads)',
      amount: '+125 GAME',
      timestamp: '2 hours ago',
      status: 'win'
    },
    {
      id: '2',
      type: 'lottery',
      description: 'Purchased 5 lottery tickets',
      amount: '-50 GAME',
      timestamp: '1 day ago',
      status: 'pending'
    },
    {
      id: '3',
      type: 'staking',
      description: 'Staked tokens for 90 days',
      amount: '-1,000 GAME',
      timestamp: '2 days ago',
      status: 'completed'
    },
    {
      id: '4',
      type: 'marketplace',
      description: 'Sold Silver Pass #123',
      amount: '+800 GAME',
      timestamp: '3 days ago',
      status: 'completed'
    },
    {
      id: '5',
      type: 'pvp',
      description: 'Lost PvP bet against Player#456',
      amount: '-100 GAME',
      timestamp: '4 days ago',
      status: 'loss'
    }
  ];

  const getChangeIcon = (changeType: string) => {
    switch (changeType) {
      case 'positive':
        return <ArrowUpIcon className="h-4 w-4 text-green-400" />;
      case 'negative':
        return <ArrowDownIcon className="h-4 w-4 text-red-400" />;
      default:
        return null;
    }
  };

  const getChangeColor = (changeType: string) => {
    switch (changeType) {
      case 'positive':
        return 'text-green-400';
      case 'negative':
        return 'text-red-400';
      default:
        return 'text-gray-400';
    }
  };

  const getActivityIcon = (type: string) => {
    switch (type) {
      case 'coinflip':
        return <CurrencyDollarIcon className="h-5 w-5 text-green-400" />;
      case 'lottery':
        return <SparklesIcon className="h-5 w-5 text-purple-400" />;
      case 'pvp':
        return <FireIcon className="h-5 w-5 text-red-400" />;
      case 'marketplace':
        return <ChartBarIcon className="h-5 w-5 text-blue-400" />;
      case 'staking':
        return <TrophyIcon className="h-5 w-5 text-yellow-400" />;
      default:
        return <ClockIcon className="h-5 w-5 text-gray-400" />;
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'win':
        return 'text-green-400';
      case 'loss':
        return 'text-red-400';
      case 'pending':
        return 'text-yellow-400';
      case 'completed':
        return 'text-blue-400';
      default:
        return 'text-gray-400';
    }
  };

  const StatCardComponent = ({ stat, isPlatform = false }: { stat: StatCard; isPlatform?: boolean }) => (
    <div className={`bg-gradient-to-br ${isPlatform ? 'from-gray-800/80' : 'from-blue-800/20'} to-gray-900/80 rounded-xl p-6 border border-gray-600/50 hover:border-gray-500/50 transition-all duration-200`}>
      <div className="flex items-center justify-between mb-4">
        <div className={`p-3 rounded-lg bg-${stat.color}-500/20`}>
          <stat.icon className={`h-6 w-6 text-${stat.color}-400`} />
        </div>
        <div className={`flex items-center gap-1 ${getChangeColor(stat.changeType)}`}>
          {getChangeIcon(stat.changeType)}
          <span className="text-sm font-medium">{stat.change}</span>
        </div>
      </div>
      <div>
        <h3 className="text-2xl font-bold text-white mb-1">{stat.value}</h3>
        <p className="text-gray-400 text-sm">{stat.title}</p>
      </div>
    </div>
  );

  if (!isConnected) {
    return (
      <div className="text-center py-12">
        <div className="mb-6">
          <ChartBarIcon className="h-16 w-16 text-gray-500 mx-auto mb-4" />
          <h3 className="text-xl font-semibold text-gray-300 mb-2">Connect Wallet to View Stats</h3>
          <p className="text-gray-500">Connect your wallet to see your personal gaming statistics and platform overview.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-8">
      {/* Platform Statistics */}
      <div>
        <h3 className="text-xl font-semibold text-white mb-4 flex items-center gap-2">
          <ChartBarIcon className="h-6 w-6 text-blue-400" />
          Platform Statistics
        </h3>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          {platformStats.map((stat, index) => (
            <StatCardComponent key={index} stat={stat} isPlatform={true} />
          ))}
        </div>
      </div>

      {/* User Statistics */}
      <div>
        <h3 className="text-xl font-semibold text-white mb-4 flex items-center gap-2">
          <TrophyIcon className="h-6 w-6 text-yellow-400" />
          Your Performance
        </h3>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          {userStats.map((stat, index) => (
            <StatCardComponent key={index} stat={stat} />
          ))}
        </div>
      </div>

      {/* Recent Activity */}
      <div>
        <h3 className="text-xl font-semibold text-white mb-4 flex items-center gap-2">
          <ClockIcon className="h-6 w-6 text-purple-400" />
          Recent Activity
        </h3>
        <div className="bg-gray-800/50 rounded-xl border border-gray-600/50">
          {recentActivity.length > 0 ? (
            <div className="divide-y divide-gray-700/50">
              {recentActivity.map((activity) => (
                <div key={activity.id} className="p-4 hover:bg-gray-700/30 transition-colors">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-3">
                      {getActivityIcon(activity.type)}
                      <div>
                        <p className="text-white font-medium">{activity.description}</p>
                        <p className="text-gray-400 text-sm">{activity.timestamp}</p>
                      </div>
                    </div>
                    <div className="text-right">
                      <p className={`font-semibold ${getStatusColor(activity.status)}`}>
                        {activity.amount}
                      </p>
                      <p className={`text-sm capitalize ${getStatusColor(activity.status)}`}>
                        {activity.status}
                      </p>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="p-8 text-center">
              <ClockIcon className="h-12 w-12 text-gray-500 mx-auto mb-3" />
              <p className="text-gray-400">No recent activity</p>
            </div>
          )}
        </div>
      </div>

      {/* Performance Chart Placeholder */}
      <div>
        <h3 className="text-xl font-semibold text-white mb-4 flex items-center gap-2">
          <ChartBarIcon className="h-6 w-6 text-green-400" />
          Performance Chart
        </h3>
        <div className="bg-gray-800/50 rounded-xl border border-gray-600/50 p-8">
          <div className="h-64 flex items-center justify-center">
            <div className="text-center">
              <ChartBarIcon className="h-16 w-16 text-gray-500 mx-auto mb-4" />
              <p className="text-gray-400">Performance chart coming soon</p>
              <p className="text-gray-500 text-sm mt-2">Track your winnings and gameplay over time</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}