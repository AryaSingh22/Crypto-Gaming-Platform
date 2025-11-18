'use client';

import React from 'react';

interface StatsCardProps {
  title: string;
  value: string;
  subtitle: string;
  icon: string;
  color: 'blue' | 'purple' | 'green' | 'yellow' | 'red';
}

const StatsCard: React.FC<StatsCardProps> = ({ title, value, subtitle, icon, color }) => {
  const colorClasses = {
    blue: 'from-blue-500 to-blue-600',
    purple: 'from-purple-500 to-purple-600',
    green: 'from-green-500 to-green-600',
    yellow: 'from-yellow-500 to-yellow-600',
    red: 'from-red-500 to-red-600',
  };

  return (
    <div className="card relative overflow-hidden">
      <div className={`absolute top-0 right-0 w-16 h-16 bg-gradient-to-br ${colorClasses[color]} opacity-20 rounded-bl-full`}></div>
      
      <div className="flex items-start justify-between">
        <div className="flex-1">
          <h3 className="text-gray-400 text-sm font-medium mb-1">{title}</h3>
          <p className="text-2xl font-bold text-white mb-1">{value}</p>
          <p className="text-gray-500 text-xs">{subtitle}</p>
        </div>
        
        <div className="text-2xl opacity-80">
          {icon}
        </div>
      </div>
      
      <div className="mt-4 pt-4 border-t border-gray-700">
        <div className="text-xs text-gray-500">
          <span className="text-green-400">↗</span> Live data
        </div>
      </div>
    </div>
  );
};

export default StatsCard;