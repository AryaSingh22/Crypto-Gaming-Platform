'use client';

import React from 'react';

interface Activity {
  id: string;
  type: 'bet' | 'win' | 'mint' | 'deposit';
  description: string;
  amount?: string;
  timestamp: string;
  status: 'completed' | 'pending' | 'failed';
}

const RecentActivity: React.FC = () => {
  // Mock data - in a real app, this would come from contract events or backend
  const activities: Activity[] = [
    {
      id: '1',
      type: 'bet',
      description: 'CoinFlip bet placed',
      amount: '100 GAME',
      timestamp: '2 minutes ago',
      status: 'pending'
    },
    {
      id: '2',
      type: 'win',
      description: 'CoinFlip win',
      amount: '196 GAME',
      timestamp: '5 minutes ago',
      status: 'completed'
    },
    {
      id: '3',
      type: 'mint',
      description: 'Bronze Pass minted',
      timestamp: '1 hour ago',
      status: 'completed'
    },
  ];

  const getIcon = (type: Activity['type']) => {
    switch (type) {
      case 'bet': return '🎲';
      case 'win': return '🏆';
      case 'mint': return '🎫';
      case 'deposit': return '💰';
      default: return '📝';
    }
  };

  const getStatusColor = (status: Activity['status']) => {
    switch (status) {
      case 'completed': return 'text-green-400';
      case 'pending': return 'text-yellow-400';
      case 'failed': return 'text-red-400';
      default: return 'text-gray-400';
    }
  };

  const getStatusIcon = (status: Activity['status']) => {
    switch (status) {
      case 'completed': return '✓';
      case 'pending': return '⏳';
      case 'failed': return '✗';
      default: return '?';
    }
  };

  return (
    <div className="card">
      <h3 className="text-xl font-semibold mb-4">Recent Activity</h3>
      
      {activities.length === 0 ? (
        <div className="text-center py-8 text-gray-500">
          <div className="text-4xl mb-2">📭</div>
          <p>No recent activity</p>
          <p className="text-sm">Start playing to see your transaction history!</p>
        </div>
      ) : (
        <div className="space-y-3">
          {activities.map((activity) => (
            <div key={activity.id} className="flex items-center justify-between p-3 bg-gray-700 rounded-lg">
              <div className="flex items-center space-x-3">
                <div className="text-xl">{getIcon(activity.type)}</div>
                <div>
                  <p className="text-white font-medium">{activity.description}</p>
                  <p className="text-gray-400 text-sm">{activity.timestamp}</p>
                </div>
              </div>
              
              <div className="text-right">
                {activity.amount && (
                  <p className="text-white font-semibold">{activity.amount}</p>
                )}
                <div className={`text-sm flex items-center space-x-1 ${getStatusColor(activity.status)}`}>
                  <span>{getStatusIcon(activity.status)}</span>
                  <span className="capitalize">{activity.status}</span>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
      
      <div className="mt-4 pt-4 border-t border-gray-700">
        <button className="text-blue-400 hover:text-blue-300 text-sm transition-colors duration-200">
          View all activity →
        </button>
      </div>
    </div>
  );
};

export default RecentActivity;