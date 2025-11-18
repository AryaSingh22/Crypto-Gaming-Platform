'use client';

import React, { useState } from 'react';
import { 
  ShoppingCartIcon, 
  ClockIcon, 
  CurrencyDollarIcon, 
  SparklesIcon,
  TagIcon,
  TrophyIcon,
  EyeIcon,
  HeartIcon,
  FilterIcon,
  GiftIcon
} from '@heroicons/react/24/outline';
import { useAccount } from 'wagmi';

interface NFTListing {
  id: string;
  tokenId: number;
  seller: string;
  tier: 'Bronze' | 'Silver' | 'Gold';
  listingType: 'fixed' | 'auction';
  price: string;
  currentBid?: string;
  highestBidder?: string;
  expiresAt?: number;
  createdAt: number;
  image: string;
  attributes: {
    level: number;
    experience: number;
    gamesPlayed: number;
    winRate: number;
  };
}

interface Bid {
  bidder: string;
  amount: string;
  timestamp: number;
}

export default function NFTMarketplace() {
  const { address, isConnected } = useAccount();
  const [activeTab, setActiveTab] = useState<'browse' | 'my-listings' | 'my-bids' | 'create'>('browse');
  const [filterTier, setFilterTier] = useState<'all' | 'Bronze' | 'Silver' | 'Gold'>('all');
  const [filterType, setFilterType] = useState<'all' | 'fixed' | 'auction'>('all');
  const [sortBy, setSortBy] = useState<'price' | 'tier' | 'time'>('price');
  const [selectedNFT, setSelectedNFT] = useState<NFTListing | null>(null);

  // Mock data - replace with actual contract calls
  const nftListings: NFTListing[] = [
    {
      id: '1',
      tokenId: 123,
      seller: '0x1234...5678',
      tier: 'Gold',
      listingType: 'auction',
      price: '2500',
      currentBid: '1800',
      highestBidder: '0x2345...6789',
      expiresAt: Date.now() + 4 * 60 * 60 * 1000,
      createdAt: Date.now() - 2 * 60 * 60 * 1000,
      image: '/api/placeholder/300/300',
      attributes: {
        level: 15,
        experience: 12500,
        gamesPlayed: 89,
        winRate: 72.5
      }
    },
    {
      id: '2',
      tokenId: 456,
      seller: '0x3456...7890',
      tier: 'Silver',
      listingType: 'fixed',
      price: '800',
      createdAt: Date.now() - 1 * 60 * 60 * 1000,
      image: '/api/placeholder/300/300',
      attributes: {
        level: 8,
        experience: 4200,
        gamesPlayed: 34,
        winRate: 68.2
      }
    },
    {
      id: '3',
      tokenId: 789,
      seller: '0x4567...8901',
      tier: 'Bronze',
      listingType: 'fixed',
      price: '150',
      createdAt: Date.now() - 30 * 60 * 1000,
      image: '/api/placeholder/300/300',
      attributes: {
        level: 3,
        experience: 850,
        gamesPlayed: 12,
        winRate: 58.3
      }
    }
  ];

  const myListings: NFTListing[] = [
    {
      id: '4',
      tokenId: 321,
      seller: address || '',
      tier: 'Silver',
      listingType: 'auction',
      price: '1000',
      currentBid: '750',
      highestBidder: '0x5678...9012',
      expiresAt: Date.now() + 6 * 60 * 60 * 1000,
      createdAt: Date.now() - 3 * 60 * 60 * 1000,
      image: '/api/placeholder/300/300',
      attributes: {
        level: 10,
        experience: 6800,
        gamesPlayed: 45,
        winRate: 75.6
      }
    }
  ];

  const myBids: { listing: NFTListing; bid: Bid }[] = [
    {
      listing: nftListings[0],
      bid: {
        bidder: address || '',
        amount: '1600',
        timestamp: Date.now() - 1 * 60 * 60 * 1000
      }
    }
  ];

  const getTierColor = (tier: string) => {
    switch (tier) {
      case 'Bronze':
        return 'from-orange-600 to-yellow-600';
      case 'Silver':
        return 'from-gray-400 to-gray-600';
      case 'Gold':
        return 'from-yellow-400 to-yellow-600';
      default:
        return 'from-gray-600 to-gray-800';
    }
  };

  const getTierBorderColor = (tier: string) => {
    switch (tier) {
      case 'Bronze':
        return 'border-orange-500/50';
      case 'Silver':
        return 'border-gray-400/50';
      case 'Gold':
        return 'border-yellow-400/50';
      default:
        return 'border-gray-600/50';
    }
  };

  const formatTimeRemaining = (ms: number) => {
    if (ms <= 0) return 'Expired';
    const hours = Math.floor(ms / (1000 * 60 * 60));
    const minutes = Math.floor((ms % (1000 * 60 * 60)) / (1000 * 60));
    if (hours > 0) return `${hours}h ${minutes}m`;
    return `${minutes}m`;
  };

  const filteredListings = nftListings.filter(listing => {
    if (filterTier !== 'all' && listing.tier !== filterTier) return false;
    if (filterType !== 'all' && listing.listingType !== filterType) return false;
    return true;
  });

  const NFTCard = ({ listing, showActions = true }: { listing: NFTListing; showActions?: boolean }) => (
    <div className={`bg-gray-800/50 rounded-xl border-2 ${getTierBorderColor(listing.tier)} hover:border-opacity-75 transition-all cursor-pointer group`}>
      {/* NFT Image */}
      <div className="relative overflow-hidden rounded-t-xl">
        <div className={`h-48 bg-gradient-to-br ${getTierColor(listing.tier)} relative`}>
          <div className="absolute inset-0 bg-black/20"></div>
          <div className="absolute top-4 left-4">
            <span className={`px-3 py-1 rounded-full text-xs font-semibold bg-black/50 text-white border ${getTierBorderColor(listing.tier)}`}>
              {listing.tier} #{listing.tokenId}
            </span>
          </div>
          <div className="absolute top-4 right-4">
            {listing.listingType === 'auction' && (
              <span className="px-2 py-1 bg-red-500/80 text-white text-xs rounded-full">
                Auction
              </span>
            )}
          </div>
          <div className="absolute inset-0 flex items-center justify-center">
            <SparklesIcon className="h-16 w-16 text-white/80" />
          </div>
        </div>
      </div>

      {/* NFT Details */}
      <div className="p-4">
        <div className="flex justify-between items-start mb-3">
          <div>
            <h3 className="text-white font-semibold">GamePass #{listing.tokenId}</h3>
            <p className="text-gray-400 text-sm">Level {listing.attributes.level}</p>
          </div>
          <div className="text-right">
            {listing.listingType === 'auction' ? (
              <div>
                <p className="text-gray-400 text-xs">Current Bid</p>
                <p className="text-white font-semibold">{listing.currentBid} GAME</p>
              </div>
            ) : (
              <div>
                <p className="text-gray-400 text-xs">Price</p>
                <p className="text-white font-semibold">{listing.price} GAME</p>
              </div>
            )}
          </div>
        </div>

        {/* Attributes */}
        <div className="grid grid-cols-2 gap-2 mb-4 text-xs">
          <div className="bg-gray-700/50 rounded p-2">
            <p className="text-gray-400">XP</p>
            <p className="text-white font-semibold">{listing.attributes.experience.toLocaleString()}</p>
          </div>
          <div className="bg-gray-700/50 rounded p-2">
            <p className="text-gray-400">Win Rate</p>
            <p className="text-white font-semibold">{listing.attributes.winRate}%</p>
          </div>
        </div>

        {/* Timing */}
        {listing.listingType === 'auction' && listing.expiresAt && (
          <div className="mb-4">
            <p className="text-gray-400 text-xs mb-1">Ends in</p>
            <p className="text-red-400 font-semibold text-sm">
              {formatTimeRemaining(listing.expiresAt - Date.now())}
            </p>
          </div>
        )}

        {/* Actions */}
        {showActions && (
          <div className="flex gap-2">
            {listing.listingType === 'auction' ? (
              <button
                disabled={listing.seller === address}
                className={`
                  flex-1 py-2 rounded-lg font-medium text-sm transition-colors
                  ${listing.seller === address
                    ? 'bg-gray-600 text-gray-400 cursor-not-allowed'
                    : 'bg-blue-600 hover:bg-blue-700 text-white'
                  }
                `}
              >
                Place Bid
              </button>
            ) : (
              <button
                disabled={listing.seller === address}
                className={`
                  flex-1 py-2 rounded-lg font-medium text-sm transition-colors
                  ${listing.seller === address
                    ? 'bg-gray-600 text-gray-400 cursor-not-allowed'
                    : 'bg-green-600 hover:bg-green-700 text-white'
                  }
                `}
              >
                Buy Now
              </button>
            )}
            <button className="px-3 py-2 bg-gray-700 hover:bg-gray-600 text-white rounded-lg transition-colors">
              <EyeIcon className="h-4 w-4" />
            </button>
          </div>
        )}

        {/* Seller */}
        <div className="mt-3 pt-3 border-t border-gray-700">
          <p className="text-gray-400 text-xs">
            Seller: {listing.seller === address ? 'You' : `${listing.seller.slice(0, 6)}...${listing.seller.slice(-4)}`}
          </p>
        </div>
      </div>
    </div>
  );

  const BrowseTab = () => (
    <div className="space-y-6">
      {/* Filters */}
      <div className="flex flex-wrap gap-4 items-center justify-between">
        <div className="flex gap-4 items-center">
          <select
            value={filterTier}
            onChange={(e) => setFilterTier(e.target.value as any)}
            className="px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm"
          >
            <option value="all">All Tiers</option>
            <option value="Bronze">Bronze</option>
            <option value="Silver">Silver</option>
            <option value="Gold">Gold</option>
          </select>
          
          <select
            value={filterType}
            onChange={(e) => setFilterType(e.target.value as any)}
            className="px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm"
          >
            <option value="all">All Types</option>
            <option value="fixed">Fixed Price</option>
            <option value="auction">Auction</option>
          </select>
          
          <select
            value={sortBy}
            onChange={(e) => setSortBy(e.target.value as any)}
            className="px-3 py-2 bg-gray-700 border border-gray-600 rounded-lg text-white text-sm"
          >
            <option value="price">Sort by Price</option>
            <option value="tier">Sort by Tier</option>
            <option value="time">Sort by Time</option>
          </select>
        </div>
        
        <div className="text-gray-400 text-sm">
          {filteredListings.length} NFT{filteredListings.length !== 1 ? 's' : ''} available
        </div>
      </div>

      {/* NFT Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {filteredListings.map((listing) => (
          <NFTCard key={listing.id} listing={listing} />
        ))}
      </div>

      {filteredListings.length === 0 && (
        <div className="text-center py-12">
          <ShoppingCartIcon className="h-16 w-16 text-gray-500 mx-auto mb-4" />
          <p className="text-gray-400">No NFTs found matching your filters</p>
        </div>
      )}
    </div>
  );

  const MyListingsTab = () => (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h3 className="text-lg font-semibold text-white">Your Active Listings</h3>
        <button
          onClick={() => setActiveTab('create')}
          className="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-medium transition-colors"
        >
          Create New Listing
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {myListings.map((listing) => (
          <div key={listing.id} className="relative">
            <NFTCard listing={listing} showActions={false} />
            <div className="mt-4 flex gap-2">
              <button className="flex-1 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg font-medium transition-colors">
                Cancel Listing
              </button>
              <button className="flex-1 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-medium transition-colors">
                Edit Price
              </button>
            </div>
          </div>
        ))}
      </div>

      {myListings.length === 0 && (
        <div className="text-center py-12">
          <TagIcon className="h-16 w-16 text-gray-500 mx-auto mb-4" />
          <p className="text-gray-400 mb-4">You have no active listings</p>
          <button
            onClick={() => setActiveTab('create')}
            className="px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-medium transition-colors"
          >
            Create Your First Listing
          </button>
        </div>
      )}
    </div>
  );

  const MyBidsTab = () => (
    <div className="space-y-4">
      <h3 className="text-lg font-semibold text-white">Your Active Bids</h3>
      
      {myBids.map(({ listing, bid }) => (
        <div key={listing.id} className="bg-gray-800/50 rounded-xl p-6 border border-gray-600/50">
          <div className="flex gap-6">
            <div className="w-24 h-24 rounded-lg overflow-hidden">
              <div className={`w-full h-full bg-gradient-to-br ${getTierColor(listing.tier)} flex items-center justify-center`}>
                <SparklesIcon className="h-8 w-8 text-white/80" />
              </div>
            </div>
            
            <div className="flex-1">
              <div className="flex justify-between items-start mb-2">
                <div>
                  <h4 className="text-white font-semibold">GamePass #{listing.tokenId}</h4>
                  <p className="text-gray-400 text-sm">{listing.tier} • Level {listing.attributes.level}</p>
                </div>
                <div className="text-right">
                  <p className="text-gray-400 text-sm">Your Bid</p>
                  <p className="text-white font-semibold">{bid.amount} GAME</p>
                </div>
              </div>
              
              <div className="flex justify-between items-center">
                <div className="text-sm text-gray-400">
                  Current highest: {listing.currentBid} GAME
                  {listing.expiresAt && (
                    <span className="ml-4">
                      Ends in {formatTimeRemaining(listing.expiresAt - Date.now())}
                    </span>
                  )}
                </div>
                
                <div className="flex gap-2">
                  <button className="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-medium transition-colors">
                    Increase Bid
                  </button>
                  <button className="px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg font-medium transition-colors">
                    Withdraw Bid
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      ))}
      
      {myBids.length === 0 && (
        <div className="text-center py-12">
          <CurrencyDollarIcon className="h-16 w-16 text-gray-500 mx-auto mb-4" />
          <p className="text-gray-400">You have no active bids</p>
        </div>
      )}
    </div>
  );

  const CreateListingTab = () => {
    const [newListing, setNewListing] = useState({
      tokenId: '',
      listingType: 'fixed' as 'fixed' | 'auction',
      price: '',
      duration: '24'
    });

    return (
      <div className="max-w-2xl mx-auto space-y-6">
        <h3 className="text-lg font-semibold text-white text-center">Create New Listing</h3>

        {/* Token ID */}
        <div>
          <label className="block text-white font-medium mb-2">GamePass Token ID</label>
          <input
            type="number"
            value={newListing.tokenId}
            onChange={(e) => setNewListing({ ...newListing, tokenId: e.target.value })}
            placeholder="Enter your NFT token ID"
            className="w-full px-4 py-3 bg-gray-800 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-blue-500"
          />
        </div>

        {/* Listing Type */}
        <div>
          <label className="block text-white font-medium mb-3">Listing Type</label>
          <div className="grid grid-cols-2 gap-3">
            <button
              onClick={() => setNewListing({ ...newListing, listingType: 'fixed' })}
              className={`
                p-4 rounded-xl border-2 text-left transition-all
                ${newListing.listingType === 'fixed'
                  ? 'border-blue-500 bg-blue-500/10'
                  : 'border-gray-600 bg-gray-800/50 hover:border-gray-500'
                }
              `}
            >
              <div className="flex items-center gap-2 mb-2">
                <TagIcon className="h-5 w-5" />
                <h4 className="text-white font-semibold">Fixed Price</h4>
              </div>
              <p className="text-gray-400 text-sm">Sell at a fixed price</p>
            </button>
            
            <button
              onClick={() => setNewListing({ ...newListing, listingType: 'auction' })}
              className={`
                p-4 rounded-xl border-2 text-left transition-all
                ${newListing.listingType === 'auction'
                  ? 'border-blue-500 bg-blue-500/10'
                  : 'border-gray-600 bg-gray-800/50 hover:border-gray-500'
                }
              `}
            >
              <div className="flex items-center gap-2 mb-2">
                <ClockIcon className="h-5 w-5" />
                <h4 className="text-white font-semibold">Auction</h4>
              </div>
              <p className="text-gray-400 text-sm">Let buyers bid on your NFT</p>
            </button>
          </div>
        </div>

        {/* Price */}
        <div>
          <label className="block text-white font-medium mb-2">
            {newListing.listingType === 'auction' ? 'Starting Price' : 'Price'}
          </label>
          <div className="relative">
            <input
              type="number"
              value={newListing.price}
              onChange={(e) => setNewListing({ ...newListing, price: e.target.value })}
              placeholder="Enter price"
              className="w-full px-4 py-3 bg-gray-800 border border-gray-600 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-blue-500"
            />
            <span className="absolute right-3 top-3 text-gray-400">GAME</span>
          </div>
        </div>

        {/* Duration (for auctions) */}
        {newListing.listingType === 'auction' && (
          <div>
            <label className="block text-white font-medium mb-2">Auction Duration</label>
            <select
              value={newListing.duration}
              onChange={(e) => setNewListing({ ...newListing, duration: e.target.value })}
              className="w-full px-4 py-3 bg-gray-800 border border-gray-600 rounded-lg text-white focus:outline-none focus:border-blue-500"
            >
              <option value="1">1 Hour</option>
              <option value="6">6 Hours</option>
              <option value="24">24 Hours</option>
              <option value="72">3 Days</option>
              <option value="168">1 Week</option>
            </select>
          </div>
        )}

        {/* Create Button */}
        <button
          disabled={!newListing.tokenId || !newListing.price || !isConnected}
          className={`
            w-full py-4 rounded-xl font-semibold text-lg transition-all
            ${newListing.tokenId && newListing.price && isConnected
              ? 'bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-700 hover:to-purple-700 text-white'
              : 'bg-gray-700 text-gray-400 cursor-not-allowed'
            }
          `}
        >
          Create Listing
        </button>
      </div>
    );
  };

  if (!isConnected) {
    return (
      <div className="text-center py-12">
        <ShoppingCartIcon className="h-16 w-16 text-gray-500 mx-auto mb-4" />
        <h3 className="text-xl font-semibold text-gray-300 mb-2">Connect Wallet to Access Marketplace</h3>
        <p className="text-gray-500">Connect your wallet to buy, sell, and auction GamePass NFTs.</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Stats */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="bg-blue-500/10 rounded-xl p-4 border border-blue-500/20">
          <div className="flex items-center gap-3">
            <ShoppingCartIcon className="h-8 w-8 text-blue-400" />
            <div>
              <p className="text-gray-400 text-sm">Listed NFTs</p>
              <p className="text-xl font-semibold text-white">{nftListings.length}</p>
            </div>
          </div>
        </div>
        
        <div className="bg-purple-500/10 rounded-xl p-4 border border-purple-500/20">
          <div className="flex items-center gap-3">
            <ClockIcon className="h-8 w-8 text-purple-400" />
            <div>
              <p className="text-gray-400 text-sm">Active Auctions</p>
              <p className="text-xl font-semibold text-white">
                {nftListings.filter(n => n.listingType === 'auction').length}
              </p>
            </div>
          </div>
        </div>
        
        <div className="bg-green-500/10 rounded-xl p-4 border border-green-500/20">
          <div className="flex items-center gap-3">
            <CurrencyDollarIcon className="h-8 w-8 text-green-400" />
            <div>
              <p className="text-gray-400 text-sm">Floor Price</p>
              <p className="text-xl font-semibold text-white">150 GAME</p>
            </div>
          </div>
        </div>
        
        <div className="bg-yellow-500/10 rounded-xl p-4 border border-yellow-500/20">
          <div className="flex items-center gap-3">
            <TrophyIcon className="h-8 w-8 text-yellow-400" />
            <div>
              <p className="text-gray-400 text-sm">24h Volume</p>
              <p className="text-xl font-semibold text-white">12.5K GAME</p>
            </div>
          </div>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex gap-2 mb-6">
        {[
          { id: 'browse', label: 'Browse', icon: ShoppingCartIcon },
          { id: 'my-listings', label: 'My Listings', icon: TagIcon },
          { id: 'my-bids', label: 'My Bids', icon: CurrencyDollarIcon },
          { id: 'create', label: 'Create Listing', icon: GiftIcon }
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
      {activeTab === 'browse' && <BrowseTab />}
      {activeTab === 'my-listings' && <MyListingsTab />}
      {activeTab === 'my-bids' && <MyBidsTab />}
      {activeTab === 'create' && <CreateListingTab />}
    </div>
  );
}