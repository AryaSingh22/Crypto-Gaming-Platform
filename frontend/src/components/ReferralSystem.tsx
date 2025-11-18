'use client';

import React, { useState } from 'react';
import { 
  UserGroupIcon, 
  ShareIcon, 
  CurrencyDollarIcon, 
  TrophyIcon,
  ChartBarIcon,
  ClipboardDocumentIcon,
  QrCodeIcon,
  GiftIcon,
  StarIcon,
  CalendarIcon
} from '@heroicons/react/24/outline';
import { useAccount } from 'wagmi';

interface ReferralData {
  totalReferrals: number;
  activeReferrals: number;
  totalEarnings: string;
  currentTier: number;
  nextTierRequirement: number;
  referralCode: string;
  registrationTime: number;
}

interface ActivityRecord {
  user: string;
  activityType: 'GamePlay' | 'NFTTrading' | 'Staking' | 'Registration';
  volume: string;
  rewards: string;
  timestamp: number;
}

interface ReferralTier {
  level: number;
  name: string;
  minReferrals: number;
  rewardRate: number;
  bonusRate: number;
  color: string;
}

export default function ReferralSystem() {
  const { address, isConnected } = useAccount();
  const [activeTab, setActiveTab] = useState<'overview' | 'invite' | 'activity' | 'leaderboard'>('overview');
  const [newReferralCode, setNewReferralCode] = useState('');
  const [inviteCode, setInviteCode] = useState('');

  // Mock data - replace with actual contract calls
  const userReferralData: ReferralData = {
    totalReferrals: 12,
    activeReferrals: 8,
    totalEarnings: '1,250.50',
    currentTier: 2,
    nextTierRequirement: 3,
    referralCode: 'CRYPTO_GAMER_123',
    registrationTime: Date.now() - 30 * 24 * 60 * 60 * 1000
  };

  const referralTiers: ReferralTier[] = [
    { level: 0, name: 'Starter', minReferrals: 0, rewardRate: 2, bonusRate: 0, color: 'gray' },
    { level: 1, name: 'Bronze', minReferrals: 5, rewardRate: 2.5, bonusRate: 0.5, color: 'orange' },
    { level: 2, name: 'Silver', minReferrals: 15, rewardRate: 3, bonusRate: 1, color: 'gray' },
    { level: 3, name: 'Gold', minReferrals: 50, rewardRate: 4, bonusRate: 2, color: 'yellow' },
    { level: 4, name: 'Platinum', minReferrals: 100, rewardRate: 5, bonusRate: 3, color: 'purple' }
  ];

  const recentActivity: ActivityRecord[] = [
    {
      user: '0x1234...5678',
      activityType: 'GamePlay',
      volume: '100',
      rewards: '2.50',
      timestamp: Date.now() - 2 * 60 * 60 * 1000
    },
    {
      user: '0x2345...6789',
      activityType: 'NFTTrading',
      volume: '500',
      rewards: '7.50',
      timestamp: Date.now() - 4 * 60 * 60 * 1000
    },
    {
      user: '0x3456...7890',
      activityType: 'Staking',
      volume: '1000',
      rewards: '10.00',
      timestamp: Date.now() - 8 * 60 * 60 * 1000
    }
  ];

  const leaderboard = [
    { address: '0x1111...1111', referrals: 156, earnings: '12,500', tier: 'Platinum' },
    { address: '0x2222...2222', referrals: 89, earnings: '7,800', tier: 'Gold' },
    { address: '0x3333...3333', referrals: 67, earnings: '5,200', tier: 'Gold' },
    { address: '0x4444...4444', referrals: 45, earnings: '3,600', tier: 'Silver' },
    { address: '0x5555...5555', referrals: 23, earnings: '1,900', tier: 'Bronze' }
  ];

  const currentTier = referralTiers[userReferralData.currentTier];
  const nextTier = referralTiers[userReferralData.currentTier + 1];

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text);
    // You could add a toast notification here
  };

  const generateReferralLink = () => {
    return `${window.location.origin}?ref=${userReferralData.referralCode}`;
  };

  const getTierColor = (tierName: string) => {
    const tier = referralTiers.find(t => t.name === tierName);
    if (!tier) return 'text-gray-400';
    
    switch (tier.color) {
      case 'orange': return 'text-orange-400';
      case 'gray': return 'text-gray-400';
      case 'yellow': return 'text-yellow-400';
      case 'purple': return 'text-purple-400';
      default: return 'text-gray-400';
    }
  };

  const getTierBgColor = (tierName: string) => {
    const tier = referralTiers.find(t => t.name === tierName);
    if (!tier) return 'bg-gray-500/20 border-gray-500/50';
    
    switch (tier.color) {
      case 'orange': return 'bg-orange-500/20 border-orange-500/50';
      case 'gray': return 'bg-gray-500/20 border-gray-500/50';
      case 'yellow': return 'bg-yellow-500/20 border-yellow-500/50';
      case 'purple': return 'bg-purple-500/20 border-purple-500/50';
      default: return 'bg-gray-500/20 border-gray-500/50';
    }
  };

  const getActivityIcon = (activityType: string) => {
    switch (activityType) {
      case 'GamePlay': return <CurrencyDollarIcon className="h-5 w-5 text-green-400" />;
      case 'NFTTrading': return <ChartBarIcon className="h-5 w-5 text-blue-400" />;
      case 'Staking': return <TrophyIcon className="h-5 w-5 text-yellow-400" />;
      case 'Registration': return <GiftIcon className="h-5 w-5 text-purple-400" />;
      default: return <UserGroupIcon className="h-5 w-5 text-gray-400" />;
    }
  };

  const OverviewTab = () => (
    <div className="space-y-6">
      {/* Current Status */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="bg-blue-500/10 rounded-xl p-6 border border-blue-500/20">
          <div className="flex items-center gap-3 mb-3">
            <UserGroupIcon className="h-8 w-8 text-blue-400" />
            <div>
              <p className="text-gray-400 text-sm">Total Referrals</p>
              <p className="text-2xl font-bold text-white">{userReferralData.totalReferrals}</p>
            </div>
          </div>
          <p className="text-green-400 text-sm">+{userReferralData.activeReferrals} active</p>
        </div>

        <div className="bg-green-500/10 rounded-xl p-6 border border-green-500/20">
          <div className="flex items-center gap-3 mb-3">
            <CurrencyDollarIcon className="h-8 w-8 text-green-400" />
            <div>
              <p className="text-gray-400 text-sm">Total Earnings</p>
              <p className="text-2xl font-bold text-white">{userReferralData.totalEarnings} GAME</p>
            </div>
          </div>
          <p className="text-green-400 text-sm">All-time rewards</p>
        </div>

        <div className={`rounded-xl p-6 border ${getTierBgColor(currentTier.name)}`}>
          <div className="flex items-center gap-3 mb-3">
            <StarIcon className={`h-8 w-8 ${getTierColor(currentTier.name)}`} />
            <div>
              <p className="text-gray-400 text-sm">Current Tier</p>
              <p className={`text-2xl font-bold ${getTierColor(currentTier.name)}`}>{currentTier.name}</p>
            </div>
          </div>
          <p className="text-gray-400 text-sm">{currentTier.rewardRate}% base rate</p>
        </div>

        <div className="bg-purple-500/10 rounded-xl p-6 border border-purple-500/20">
          <div className="flex items-center gap-3 mb-3">
            <TrophyIcon className="h-8 w-8 text-purple-400" />
            <div>
              <p className="text-gray-400 text-sm">Next Tier</p>
              <p className="text-2xl font-bold text-white">
                {nextTier ? nextTier.name : 'Max Level'}
              </p>
            </div>
          </div>
          <p className="text-purple-400 text-sm">
            {nextTier ? `${userReferralData.nextTierRequirement} more needed` : 'Achieved!'}
          </p>
        </div>
      </div>

      {/* Tier Progress */}
      {nextTier && (
        <div className="bg-gray-800/50 rounded-xl p-6 border border-gray-600/50">
          <h3 className="text-lg font-semibold text-white mb-4">Tier Progress</h3>
          <div className="flex items-center justify-between mb-2">
            <span className={`font-semibold ${getTierColor(currentTier.name)}`}>
              {currentTier.name}
            </span>
            <span className={`font-semibold ${getTierColor(nextTier.name)}`}>
              {nextTier.name}
            </span>
          </div>
          <div className="w-full bg-gray-700 rounded-full h-3 mb-4">
            <div 
              className="bg-gradient-to-r from-blue-500 to-purple-500 h-3 rounded-full transition-all duration-500"
              style={{ 
                width: `${((userReferralData.totalReferrals - currentTier.minReferrals) / 
                        (nextTier.minReferrals - currentTier.minReferrals)) * 100}%` 
              }}
            ></div>
          </div>
          <div className="flex justify-between text-sm text-gray-400">
            <span>{userReferralData.totalReferrals} referrals</span>
            <span>{nextTier.minReferrals} required</span>
          </div>
        </div>
      )}

      {/* Tier Benefits */}
      <div className="bg-gray-800/50 rounded-xl p-6 border border-gray-600/50">
        <h3 className="text-lg font-semibold text-white mb-4">All Tiers & Benefits</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {referralTiers.map((tier) => (
            <div 
              key={tier.level}
              className={`
                p-4 rounded-lg border-2 transition-all
                ${tier.level === userReferralData.currentTier 
                  ? getTierBgColor(tier.name) 
                  : 'bg-gray-700/30 border-gray-600/50'
                }
              `}
            >
              <div className="flex items-center gap-2 mb-2">
                <StarIcon className={`h-5 w-5 ${getTierColor(tier.name)}`} />
                <h4 className={`font-semibold ${getTierColor(tier.name)}`}>{tier.name}</h4>
                {tier.level === userReferralData.currentTier && (
                  <span className="px-2 py-1 bg-blue-500/20 text-blue-400 text-xs rounded-full">Current</span>
                )}
              </div>
              <div className="text-sm text-gray-300 space-y-1">
                <p>• {tier.minReferrals}+ referrals required</p>
                <p>• {tier.rewardRate}% base reward rate</p>
                <p>• +{tier.bonusRate}% tier bonus</p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );

  const InviteTab = () => (
    <div className="max-w-2xl mx-auto space-y-6">
      <div className="text-center">
        <h3 className="text-2xl font-bold text-white mb-2">Invite Friends & Earn Rewards</h3>
        <p className="text-gray-400">
          Share your referral link and earn {currentTier.rewardRate}% on all their activities
        </p>
      </div>

      {/* Referral Code */}
      <div className="bg-gray-800/50 rounded-xl p-6 border border-gray-600/50">
        <h4 className="text-lg font-semibold text-white mb-4">Your Referral Code</h4>
        <div className="flex gap-3">
          <div className="flex-1 px-4 py-3 bg-gray-700 border border-gray-600 rounded-lg">
            <p className="text-white font-mono text-lg">{userReferralData.referralCode}</p>
          </div>
          <button
            onClick={() => copyToClipboard(userReferralData.referralCode)}
            className="px-4 py-3 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition-colors"
          >
            <ClipboardDocumentIcon className="h-5 w-5" />
          </button>
        </div>
      </div>

      {/* Referral Link */}
      <div className="bg-gray-800/50 rounded-xl p-6 border border-gray-600/50">
        <h4 className="text-lg font-semibold text-white mb-4">Your Referral Link</h4>
        <div className="flex gap-3 mb-4">
          <div className="flex-1 px-4 py-3 bg-gray-700 border border-gray-600 rounded-lg">
            <p className="text-white text-sm break-all">{generateReferralLink()}</p>
          </div>
          <button
            onClick={() => copyToClipboard(generateReferralLink())}
            className="px-4 py-3 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition-colors"
          >
            <ClipboardDocumentIcon className="h-5 w-5" />
          </button>
        </div>
        
        <div className="flex gap-3">
          <button className="flex-1 px-4 py-3 bg-green-600 hover:bg-green-700 text-white rounded-lg font-medium transition-colors">
            <ShareIcon className="h-5 w-5 inline mr-2" />
            Share Link
          </button>
          <button className="px-4 py-3 bg-purple-600 hover:bg-purple-700 text-white rounded-lg transition-colors">
            <QrCodeIcon className="h-5 w-5" />
          </button>
        </div>
      </div>

      {/* Update Referral Code */}
      <div className="bg-gray-800/50 rounded-xl p-6 border border-gray-600/50">
        <h4 className="text-lg font-semibold text-white mb-4">Update Referral Code</h4>
        <div className="flex gap-3">
          <input
            type="text"
            value={newReferralCode}
            onChange={(e) => setNewReferralCode(e.target.value)}
            placeholder="Enter new referral code"
            maxLength={20}
            className="flex-1 px-4 py-3 bg-gray-700 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-blue-500"
          />
          <button
            disabled={!newReferralCode || newReferralCode === userReferralData.referralCode}
            className={`
              px-6 py-3 rounded-lg font-medium transition-colors
              ${newReferralCode && newReferralCode !== userReferralData.referralCode
                ? 'bg-blue-600 hover:bg-blue-700 text-white'
                : 'bg-gray-600 text-gray-400 cursor-not-allowed'
              }
            `}
          >
            Update
          </button>
        </div>
        <p className="text-gray-400 text-sm mt-2">
          Choose a memorable code (up to 20 characters, letters and numbers only)
        </p>
      </div>

      {/* How It Works */}
      <div className="bg-gradient-to-r from-blue-500/10 to-purple-500/10 rounded-xl p-6 border border-blue-500/20">
        <h4 className="text-lg font-semibold text-white mb-4">How Referrals Work</h4>
        <div className="space-y-3 text-sm text-gray-300">
          <div className="flex items-start gap-3">
            <div className="w-6 h-6 bg-blue-500 rounded-full flex items-center justify-center text-white text-xs font-bold">1</div>
            <p>Share your referral link with friends</p>
          </div>
          <div className="flex items-start gap-3">
            <div className="w-6 h-6 bg-blue-500 rounded-full flex items-center justify-center text-white text-xs font-bold">2</div>
            <p>They sign up using your link and get access to the platform</p>
          </div>
          <div className="flex items-start gap-3">
            <div className="w-6 h-6 bg-blue-500 rounded-full flex items-center justify-center text-white text-xs font-bold">3</div>
            <p>You earn {currentTier.rewardRate}% of their activity volume as rewards</p>
          </div>
          <div className="flex items-start gap-3">
            <div className="w-6 h-6 bg-blue-500 rounded-full flex items-center justify-center text-white text-xs font-bold">4</div>
            <p>Refer more users to unlock higher tiers and better rates</p>
          </div>
        </div>
      </div>
    </div>
  );

  const ActivityTab = () => (
    <div className="space-y-6">
      <h3 className="text-lg font-semibold text-white">Recent Activity</h3>
      
      <div className="space-y-3">
        {recentActivity.map((activity, index) => (
          <div key={index} className="bg-gray-800/50 rounded-xl p-4 border border-gray-600/50">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                {getActivityIcon(activity.activityType)}
                <div>
                  <p className="text-white font-medium">{activity.activityType}</p>
                  <p className="text-gray-400 text-sm">
                    by {activity.user.slice(0, 6)}...{activity.user.slice(-4)}
                  </p>
                </div>
              </div>
              
              <div className="text-right">
                <p className="text-green-400 font-semibold">+{activity.rewards} GAME</p>
                <p className="text-gray-400 text-sm">{activity.volume} GAME volume</p>
              </div>
            </div>
            
            <div className="mt-3 pt-3 border-t border-gray-700">
              <p className="text-gray-400 text-sm">
                {new Date(activity.timestamp).toLocaleString()}
              </p>
            </div>
          </div>
        ))}
      </div>

      {recentActivity.length === 0 && (
        <div className="text-center py-12">
          <CalendarIcon className="h-16 w-16 text-gray-500 mx-auto mb-4" />
          <p className="text-gray-400">No referral activity yet</p>
        </div>
      )}
    </div>
  );

  const LeaderboardTab = () => (
    <div className="space-y-6">
      <h3 className="text-lg font-semibold text-white">Top Referrers</h3>
      
      <div className="space-y-3">
        {leaderboard.map((user, index) => (
          <div key={index} className="bg-gray-800/50 rounded-xl p-4 border border-gray-600/50">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className={`
                  w-8 h-8 rounded-full flex items-center justify-center font-bold text-sm
                  ${index === 0 ? 'bg-yellow-500 text-black' :
                    index === 1 ? 'bg-gray-400 text-black' :
                    index === 2 ? 'bg-orange-500 text-black' :
                    'bg-gray-600 text-white'
                  }
                `}>
                  {index + 1}
                </div>
                <div>
                  <p className="text-white font-medium">
                    {user.address === address ? 'You' : `${user.address.slice(0, 6)}...${user.address.slice(-4)}`}
                  </p>
                  <p className={`text-sm ${getTierColor(user.tier)}`}>{user.tier} Tier</p>
                </div>
              </div>
              
              <div className="text-right">
                <p className="text-white font-semibold">{user.referrals} referrals</p>
                <p className="text-green-400 text-sm">{user.earnings} GAME earned</p>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );

  if (!isConnected) {
    return (
      <div className="text-center py-12">
        <UserGroupIcon className="h-16 w-16 text-gray-500 mx-auto mb-4" />
        <h3 className="text-xl font-semibold text-gray-300 mb-2">Connect Wallet for Referrals</h3>
        <p className="text-gray-500">Connect your wallet to start earning referral rewards.</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Tabs */}
      <div className="flex gap-2 mb-6">
        {[
          { id: 'overview', label: 'Overview', icon: ChartBarIcon },
          { id: 'invite', label: 'Invite Friends', icon: ShareIcon },
          { id: 'activity', label: 'Activity', icon: CalendarIcon },
          { id: 'leaderboard', label: 'Leaderboard', icon: TrophyIcon }
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
      {activeTab === 'overview' && <OverviewTab />}
      {activeTab === 'invite' && <InviteTab />}
      {activeTab === 'activity' && <ActivityTab />}
      {activeTab === 'leaderboard' && <LeaderboardTab />}
    </div>
  );
}