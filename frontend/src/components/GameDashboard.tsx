'use client';

import React, { useState } from 'react';
import { Tab } from '@headlessui/react';
import { 
  CurrencyDollarIcon, 
  SparklesIcon, 
  FireIcon, 
  ShoppingCartIcon, 
  BanknotesIcon,
  ChartBarIcon,
  TrophyIcon,
  UserGroupIcon,
  ShareIcon
} from '@heroicons/react/24/outline';
import CoinFlipGame from './CoinFlipGame';
import LotteryGame from './LotteryGame';
import PvPBetting from './PvPBetting';
import NFTMarketplace from './NFTMarketplace';
import StakingInterface from './StakingInterface';
import StatsOverview from './StatsOverview';
import ReferralSystem from './ReferralSystem';
import Leaderboards from './Leaderboards';

interface GameTab {
  name: string;
  icon: React.ComponentType<{ className?: string }>;
  component: React.ComponentType;
  description: string;
  color: string;
}

const gameTabs: GameTab[] = [
  {
    name: 'Overview',
    icon: ChartBarIcon,
    component: StatsOverview,
    description: 'Platform statistics and your portfolio',
    color: 'blue'
  },
  {
    name: 'CoinFlip',
    icon: CurrencyDollarIcon,
    component: CoinFlipGame,
    description: 'Provably fair 50/50 betting game',
    color: 'green'
  },
  {
    name: 'Lottery',
    icon: SparklesIcon,
    component: LotteryGame,
    description: 'Weekly lottery with VRF-powered draws',
    color: 'purple'
  },
  {
    name: 'PvP Betting',
    icon: FireIcon,
    component: PvPBetting,
    description: 'Peer-to-peer betting and challenges',
    color: 'red'
  },
  {
    name: 'Marketplace',
    icon: ShoppingCartIcon,
    component: NFTMarketplace,
    description: 'Trade and auction your NFT passes',
    color: 'indigo'
  },
  {
    name: 'Staking',
    icon: BanknotesIcon,
    component: StakingInterface,
    description: 'Stake GAME tokens and earn rewards',
    color: 'yellow'
  },
  {
    name: 'Referrals',
    icon: ShareIcon,
    component: ReferralSystem,
    description: 'Invite friends and earn referral rewards',
    color: 'pink'
  },
  {
    name: 'Leaderboards',
    icon: TrophyIcon,
    component: Leaderboards,
    description: 'Rankings, achievements, and community features',
    color: 'purple'
  }
];

function classNames(...classes: string[]) {
  return classes.filter(Boolean).join(' ');
}

export default function GameDashboard() {
  const [selectedIndex, setSelectedIndex] = useState(0);

  const getTabColorClasses = (color: string, selected: boolean) => {
    const baseClasses = 'transition-all duration-200';
    
    if (selected) {
      switch (color) {
        case 'blue': return `${baseClasses} bg-blue-500/20 border-blue-400 text-blue-300`;
        case 'green': return `${baseClasses} bg-green-500/20 border-green-400 text-green-300`;
        case 'purple': return `${baseClasses} bg-purple-500/20 border-purple-400 text-purple-300`;
        case 'red': return `${baseClasses} bg-red-500/20 border-red-400 text-red-300`;
        case 'indigo': return `${baseClasses} bg-indigo-500/20 border-indigo-400 text-indigo-300`;
        case 'yellow': return `${baseClasses} bg-yellow-500/20 border-yellow-400 text-yellow-300`;
        case 'pink': return `${baseClasses} bg-pink-500/20 border-pink-400 text-pink-300`;
        case 'purple': return `${baseClasses} bg-purple-500/20 border-purple-400 text-purple-300`;
        default: return `${baseClasses} bg-gray-500/20 border-gray-400 text-gray-300`;
      }
    } else {
      return `${baseClasses} bg-gray-800/50 border-gray-600 text-gray-400 hover:bg-gray-700/50 hover:border-gray-500 hover:text-gray-300`;
    }
  };

  const getIconColorClasses = (color: string, selected: boolean) => {
    if (selected) {
      switch (color) {
        case 'blue': return 'text-blue-400';
        case 'green': return 'text-green-400';
        case 'purple': return 'text-purple-400';
        case 'red': return 'text-red-400';
        case 'indigo': return 'text-indigo-400';
        case 'yellow': return 'text-yellow-400';
        case 'pink': return 'text-pink-400';
        case 'purple': return 'text-purple-400';
        default: return 'text-gray-400';
      }
    }
    return 'text-gray-500 group-hover:text-gray-400';
  };

  return (
    <div className="w-full max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div className="mb-8">
        <h2 className="text-3xl font-bold text-center mb-4 bg-gradient-to-r from-blue-400 to-purple-400 bg-clip-text text-transparent">
          Gaming Dashboard
        </h2>
        <p className="text-gray-400 text-center max-w-2xl mx-auto">
          Access all platform features from one unified dashboard. Switch between games, 
          manage your portfolio, track referrals, and more.
        </p>
      </div>

      <Tab.Group selectedIndex={selectedIndex} onChange={setSelectedIndex}>
        <Tab.List className="flex flex-wrap justify-center gap-2 mb-8 p-2 bg-gray-800/30 rounded-2xl backdrop-blur-sm">
          {gameTabs.map((tab, index) => (
            <Tab
              key={tab.name}
              className={({ selected }) =>
                classNames(
                  'group flex items-center gap-3 px-4 py-3 rounded-xl border-2 font-medium text-sm',
                  'focus:outline-none focus:ring-2 focus:ring-blue-500/50',
                  'min-w-[140px] justify-center',
                  getTabColorClasses(tab.color, selected)
                )
              }
            >
              {({ selected }) => (
                <>
                  <tab.icon 
                    className={classNames(
                      'h-5 w-5 transition-colors',
                      getIconColorClasses(tab.color, selected)
                    )} 
                  />
                  <span className="whitespace-nowrap">{tab.name}</span>
                </>
              )}
            </Tab>
          ))}
        </Tab.List>

        <Tab.Panels>
          {gameTabs.map((tab, index) => (
            <Tab.Panel
              key={tab.name}
              className="focus:outline-none"
            >
              <div className="mb-6 text-center">
                <div className="flex items-center justify-center gap-3 mb-2">
                  <tab.icon className={`h-6 w-6 ${getIconColorClasses(tab.color, true)}`} />
                  <h3 className="text-2xl font-bold text-white">{tab.name}</h3>
                </div>
                <p className="text-gray-400 max-w-md mx-auto">{tab.description}</p>
              </div>

              <div className="bg-gray-800/50 backdrop-blur-sm rounded-2xl border border-gray-700/50 p-6 min-h-[600px]">
                <tab.component />
              </div>
            </Tab.Panel>
          ))}
        </Tab.Panels>
      </Tab.Group>

      {/* Quick Stats Bar */}
      <div className="mt-8 grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="bg-gradient-to-r from-blue-500/10 to-purple-500/10 rounded-xl p-4 border border-blue-500/20">
          <div className="flex items-center gap-3">
            <TrophyIcon className="h-6 w-6 text-yellow-400" />
            <div>
              <p className="text-sm text-gray-400">Current Game</p>
              <p className="text-lg font-semibold text-white">{gameTabs[selectedIndex].name}</p>
            </div>
          </div>
        </div>

        <div className="bg-gradient-to-r from-green-500/10 to-blue-500/10 rounded-xl p-4 border border-green-500/20">
          <div className="flex items-center gap-3">
            <UserGroupIcon className="h-6 w-6 text-green-400" />
            <div>
              <p className="text-sm text-gray-400">Active Players</p>
              <p className="text-lg font-semibold text-white">1,234</p>
            </div>
          </div>
        </div>

        <div className="bg-gradient-to-r from-purple-500/10 to-pink-500/10 rounded-xl p-4 border border-purple-500/20">
          <div className="flex items-center gap-3">
            <SparklesIcon className="h-6 w-6 text-purple-400" />
            <div>
              <p className="text-sm text-gray-400">Total Value Locked</p>
              <p className="text-lg font-semibold text-white">$2.1M</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}