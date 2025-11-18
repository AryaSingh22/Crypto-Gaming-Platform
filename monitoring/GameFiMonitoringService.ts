import { ethers, WebSocketProvider } from 'ethers';

/**
 * GameFi Platform Monitoring Service
 * 
 * Provides real-time monitoring of smart contracts, transaction patterns,
 * security alerts, and automated response to threats.
 */

// Configuration interfaces
interface MonitoringConfig {
  provider: ethers.Provider;
  contracts: ContractAddresses;
  alertChannels: AlertChannel[];
  thresholds: AlertThresholds;
  circuitBreakers: CircuitBreakerConfig;
}

interface ContractAddresses {
  gameToken: string;
  gamePass: string;
  coinFlip: string;
  lottery: string;
  pvpBetting: string;
  stakingPool: string;
  marketplace: string;
  referralSystem: string;
  monitoringSystem: string;
}

interface AlertChannel {
  type: 'webhook' | 'email' | 'slack' | 'telegram';
  url: string;
  severity: AlertSeverity[];
}

interface AlertThresholds {
  largeTransfer: bigint;        // Alert on transfers > this amount
  rapidTransactions: number;    // Alert on > this many txns per minute
  gasPrice: bigint;            // Alert on gas price > this amount
  failureRate: number;         // Alert if failure rate > this percentage
  volumeSpike: number;         // Alert on volume increase > this percentage
}

interface CircuitBreakerConfig {
  maxVolumePerHour: bigint;
  maxTransactionsPerBlock: number;
  maxFailureRate: number;
  enabled: boolean;
}

enum AlertSeverity {
  INFO = 'info',
  WARNING = 'warning',
  CRITICAL = 'critical',
  EMERGENCY = 'emergency'
}

// Monitoring metrics
interface TransactionMetrics {
  totalVolume: bigint;
  transactionCount: number;
  failureCount: number;
  averageGasUsed: bigint;
  lastHourVolume: bigint;
  lastBlockTransactions: number;
}

interface SecurityMetrics {
  suspiciousAddresses: Set<string>;
  largeTransfers: Array<{ from: string; to: string; amount: bigint; timestamp: number }>;
  failedTransactions: Array<{ hash: string; reason: string; timestamp: number }>;
  gasAnomalies: Array<{ hash: string; gasUsed: bigint; timestamp: number }>;
}

class GameFiMonitoringService {
  private config: MonitoringConfig;
  private contracts: { [key: string]: ethers.Contract } = {};
  private metrics: TransactionMetrics;
  private securityMetrics: SecurityMetrics;
  private isRunning: boolean = false;
  private alertRateLimiter: Map<string, number> = new Map();

  constructor(config: MonitoringConfig) {
    this.config = config;
    this.metrics = {
      totalVolume: BigInt(0),
      transactionCount: 0,
      failureCount: 0,
      averageGasUsed: BigInt(0),
      lastHourVolume: BigInt(0),
      lastBlockTransactions: 0
    };
    this.securityMetrics = {
      suspiciousAddresses: new Set(),
      largeTransfers: [],
      failedTransactions: [],
      gasAnomalies: []
    };
    
    this.initializeContracts();
  }

  private initializeContracts(): void {
    // Initialize contract instances with ABIs
    const contractConfigs = [
      { name: 'gameToken', address: this.config.contracts.gameToken },
      { name: 'gamePass', address: this.config.contracts.gamePass },
      { name: 'coinFlip', address: this.config.contracts.coinFlip },
      { name: 'lottery', address: this.config.contracts.lottery },
      { name: 'pvpBetting', address: this.config.contracts.pvpBetting },
      { name: 'stakingPool', address: this.config.contracts.stakingPool },
      { name: 'marketplace', address: this.config.contracts.marketplace },
      { name: 'referralSystem', address: this.config.contracts.referralSystem },
      { name: 'monitoringSystem', address: this.config.contracts.monitoringSystem }
    ];

    contractConfigs.forEach(({ name, address }) => {
      // In a real implementation, you would load the actual ABI
      this.contracts[name] = new ethers.Contract(address, [], this.config.provider);
    });
  }

  /**
   * Start the monitoring service
   */
  async start(): Promise<void> {
    if (this.isRunning) {
      console.log('Monitoring service is already running');
      return;
    }

    console.log('Starting GameFi monitoring service...');
    this.isRunning = true;

    // Start various monitoring components
    await Promise.all([
      this.startBlockMonitoring(),
      this.startEventMonitoring(),
      this.startMemPoolMonitoring(),
      this.startPeriodicChecks()
    ]);

    console.log('Monitoring service started successfully');
  }

  /**
   * Stop the monitoring service
   */
  stop(): void {
    console.log('Stopping monitoring service...');
    this.isRunning = false;
  }

  /**
   * Monitor new blocks for suspicious activity
   */
  private async startBlockMonitoring(): Promise<void> {
    this.config.provider.on('block', async (blockNumber: number) => {
      if (!this.isRunning) return;

      try {
        const block = await this.config.provider.getBlock(blockNumber, true);
        if (!block || !block.transactions) return;

        await this.analyzeBlock(block);
      } catch (error) {
        console.error('Error monitoring block:', error);
        await this.sendAlert(AlertSeverity.WARNING, 'Block monitoring error', { error: error.message });
      }
    });
  }

  /**
   * Monitor smart contract events
   */
  private async startEventMonitoring(): Promise<void> {
    // Monitor GameToken transfers
    this.contracts.gameToken.on('Transfer', async (from: string, to: string, amount: bigint, event: any) => {
      await this.handleTransferEvent(from, to, amount, event);
    });

    // Monitor CoinFlip bets
    this.contracts.coinFlip.on('BetPlaced', async (betId: bigint, player: string, amount: bigint, event: any) => {
      await this.handleBetEvent(betId, player, amount, event);
    });

    // Monitor emergency events
    this.contracts.monitoringSystem.on('EmergencyStop', async (reason: string, event: any) => {
      await this.handleEmergencyStop(reason, event);
    });

    // Monitor security alerts
    this.contracts.monitoringSystem.on('SecurityAlertRaised', async (alertId: bigint, severity: number, alertType: string, target: string, event: any) => {
      await this.handleSecurityAlert(alertId, severity, alertType, target, event);
    });
  }

  /**
   * Monitor mempool for MEV and front-running attempts
   */
  private async startMemPoolMonitoring(): Promise<void> {
    if (!(this.config.provider instanceof WebSocketProvider)) {
      console.warn('Mempool monitoring requires WebSocket provider');
      return;
    }

    // In a real implementation, you would use a mempool service
    // This is a placeholder for mempool monitoring logic
    console.log('Mempool monitoring started (placeholder)');
  }

  /**
   * Run periodic health checks and maintenance
   */
  private async startPeriodicChecks(): Promise<void> {
    setInterval(async () => {
      if (!this.isRunning) return;

      try {
        await this.runHealthChecks();
        await this.updateMetrics();
        await this.checkCircuitBreakers();
        await this.cleanupOldData();
      } catch (error) {
        console.error('Error in periodic checks:', error);
      }
    }, 60000); // Run every minute
  }

  /**
   * Analyze a block for suspicious activity
   */
  private async analyzeBlock(block: ethers.Block): Promise<void> {
    if (!block.transactions) return;

    let blockTransactionCount = 0;
    let blockVolumeTotal = BigInt(0);
    let suspiciousTransactions = 0;

    for (const txHash of block.transactions) {
      try {
        const tx = await this.config.provider.getTransaction(txHash);
        const receipt = await this.config.provider.getTransactionReceipt(txHash);
        
        if (!tx || !receipt) continue;

        blockTransactionCount++;
        this.metrics.transactionCount++;

        // Analyze transaction
        await this.analyzeTransaction(tx, receipt);

        // Check for high gas usage
        if (receipt.gasUsed > this.config.thresholds.gasPrice) {
          this.securityMetrics.gasAnomalies.push({
            hash: txHash,
            gasUsed: receipt.gasUsed,
            timestamp: Date.now()
          });
          suspiciousTransactions++;
        }

        // Update metrics
        this.metrics.averageGasUsed = (this.metrics.averageGasUsed + receipt.gasUsed) / BigInt(2);

      } catch (error) {
        this.metrics.failureCount++;
        this.securityMetrics.failedTransactions.push({
          hash: txHash,
          reason: error.message,
          timestamp: Date.now()
        });
      }
    }

    // Check circuit breakers
    this.metrics.lastBlockTransactions = blockTransactionCount;
    if (blockTransactionCount > this.config.circuitBreakers.maxTransactionsPerBlock) {
      await this.triggerCircuitBreaker('Too many transactions per block', { count: blockTransactionCount });
    }

    // Alert on suspicious activity
    if (suspiciousTransactions > blockTransactionCount * 0.1) { // >10% suspicious
      await this.sendAlert(AlertSeverity.WARNING, 'High suspicious transaction rate in block', {
        blockNumber: block.number,
        suspicious: suspiciousTransactions,
        total: blockTransactionCount
      });
    }
  }

  /**
   * Analyze individual transaction
   */
  private async analyzeTransaction(tx: ethers.TransactionResponse, receipt: ethers.TransactionReceipt): Promise<void> {
    // Check if transaction failed
    if (receipt.status === 0) {
      this.metrics.failureCount++;
      return;
    }

    // Check for interactions with our contracts
    const contractInteraction = Object.values(this.config.contracts).includes(tx.to || '');
    if (!contractInteraction) return;

    // Analyze gas price
    if (tx.gasPrice && tx.gasPrice > this.config.thresholds.gasPrice * BigInt(2)) {
      await this.sendAlert(AlertSeverity.INFO, 'High gas price transaction', {
        hash: tx.hash,
        gasPrice: tx.gasPrice.toString(),
        from: tx.from
      });
    }

    // Check for large value transfers
    if (tx.value > this.config.thresholds.largeTransfer) {
      await this.sendAlert(AlertSeverity.WARNING, 'Large ETH transfer', {
        hash: tx.hash,
        value: tx.value.toString(),
        from: tx.from,
        to: tx.to
      });
    }
  }

  /**
   * Handle GameToken transfer events
   */
  private async handleTransferEvent(from: string, to: string, amount: bigint, event: any): Promise<void> {
    this.metrics.totalVolume += amount;

    // Check for large transfers
    if (amount > this.config.thresholds.largeTransfer) {
      this.securityMetrics.largeTransfers.push({
        from,
        to,
        amount,
        timestamp: Date.now()
      });

      await this.sendAlert(AlertSeverity.WARNING, 'Large token transfer detected', {
        from,
        to,
        amount: amount.toString(),
        txHash: event.transactionHash
      });
    }

    // Check for rapid transfers from same address
    const recentTransfers = this.securityMetrics.largeTransfers
      .filter(t => t.from === from && Date.now() - t.timestamp < 60000) // Last minute
      .length;

    if (recentTransfers > 5) {
      this.securityMetrics.suspiciousAddresses.add(from);
      await this.sendAlert(AlertSeverity.CRITICAL, 'Rapid transfer pattern detected', {
        address: from,
        transfers: recentTransfers
      });
    }
  }

  /**
   * Handle betting events
   */
  private async handleBetEvent(betId: bigint, player: string, amount: bigint, event: any): Promise<void> {
    // Check for unusually large bets
    if (amount > this.config.thresholds.largeTransfer) {
      await this.sendAlert(AlertSeverity.INFO, 'Large bet placed', {
        betId: betId.toString(),
        player,
        amount: amount.toString()
      });
    }

    // Track betting patterns for potential problem gambling
    // This would integrate with responsible gaming measures
  }

  /**
   * Handle emergency stop events
   */
  private async handleEmergencyStop(reason: string, event: any): Promise<void> {
    await this.sendAlert(AlertSeverity.EMERGENCY, 'Emergency stop triggered', {
      reason,
      txHash: event.transactionHash,
      blockNumber: event.blockNumber
    });

    // Additional emergency response procedures would go here
  }

  /**
   * Handle security alerts from monitoring contract
   */
  private async handleSecurityAlert(alertId: bigint, severity: number, alertType: string, target: string, event: any): Promise<void> {
    const severityMap = [AlertSeverity.INFO, AlertSeverity.WARNING, AlertSeverity.CRITICAL, AlertSeverity.EMERGENCY];
    const alertSeverity = severityMap[severity] || AlertSeverity.WARNING;

    await this.sendAlert(alertSeverity, `Smart contract alert: ${alertType}`, {
      alertId: alertId.toString(),
      target,
      txHash: event.transactionHash
    });
  }

  /**
   * Run health checks on the system
   */
  private async runHealthChecks(): Promise<void> {
    try {
      // Check contract health
      for (const [name, contract] of Object.entries(this.contracts)) {
        try {
          await this.config.provider.getCode(contract.target as string);
        } catch (error) {
          await this.sendAlert(AlertSeverity.CRITICAL, `Contract health check failed: ${name}`, {
            contract: name,
            address: contract.target as string,
            error: error.message
          });
        }
      }

      // Check provider connection
      const latestBlock = await this.config.provider.getBlockNumber();
      if (!latestBlock) {
        await this.sendAlert(AlertSeverity.CRITICAL, 'Provider connection lost', {});
      }

      // Check failure rate
      const failureRate = this.metrics.failureCount / this.metrics.transactionCount;
      if (failureRate > this.config.thresholds.failureRate / 100) {
        await this.sendAlert(AlertSeverity.WARNING, 'High transaction failure rate', {
          rate: `${(failureRate * 100).toFixed(2)}%`,
          failures: this.metrics.failureCount,
          total: this.metrics.transactionCount
        });
      }

    } catch (error) {
      console.error('Health check error:', error);
    }
  }

  /**
   * Update monitoring metrics
   */
  private async updateMetrics(): Promise<void> {
    // Reset hourly metrics
    const now = Date.now();
    const oneHourAgo = now - 3600000;

    this.securityMetrics.largeTransfers = this.securityMetrics.largeTransfers
      .filter(t => t.timestamp > oneHourAgo);

    this.securityMetrics.failedTransactions = this.securityMetrics.failedTransactions
      .filter(t => t.timestamp > oneHourAgo);

    this.securityMetrics.gasAnomalies = this.securityMetrics.gasAnomalies
      .filter(t => t.timestamp > oneHourAgo);

    // Calculate hourly volume
    this.metrics.lastHourVolume = this.securityMetrics.largeTransfers
      .reduce((sum, t) => sum + t.amount, BigInt(0));
  }

  /**
   * Check circuit breaker conditions
   */
  private async checkCircuitBreakers(): Promise<void> {
    if (!this.config.circuitBreakers.enabled) return;

    // Check hourly volume
    if (this.metrics.lastHourVolume > this.config.circuitBreakers.maxVolumePerHour) {
      await this.triggerCircuitBreaker('Hourly volume limit exceeded', {
        volume: this.metrics.lastHourVolume.toString(),
        limit: this.config.circuitBreakers.maxVolumePerHour.toString()
      });
    }

    // Check failure rate
    const failureRate = this.metrics.failureCount / this.metrics.transactionCount;
    if (failureRate > this.config.circuitBreakers.maxFailureRate / 100) {
      await this.triggerCircuitBreaker('High failure rate detected', {
        rate: `${(failureRate * 100).toFixed(2)}%`
      });
    }
  }

  /**
   * Trigger circuit breaker
   */
  private async triggerCircuitBreaker(reason: string, data: any): Promise<void> {
    await this.sendAlert(AlertSeverity.EMERGENCY, `Circuit breaker triggered: ${reason}`, data);

    // In a real implementation, this would pause contracts or limit functionality
    console.log('CIRCUIT BREAKER TRIGGERED:', reason, data);
  }

  /**
   * Clean up old monitoring data
   */
  private async cleanupOldData(): Promise<void> {
    const oneDayAgo = Date.now() - 86400000;

    // Clean up old security metrics
    this.securityMetrics.largeTransfers = this.securityMetrics.largeTransfers
      .filter(t => t.timestamp > oneDayAgo);

    this.securityMetrics.failedTransactions = this.securityMetrics.failedTransactions
      .filter(t => t.timestamp > oneDayAgo);

    this.securityMetrics.gasAnomalies = this.securityMetrics.gasAnomalies
      .filter(t => t.timestamp > oneDayAgo);

    // Clean up rate limiter
    for (const [key, timestamp] of this.alertRateLimiter.entries()) {
      if (timestamp < oneDayAgo) {
        this.alertRateLimiter.delete(key);
      }
    }
  }

  /**
   * Send alert through configured channels
   */
  private async sendAlert(severity: AlertSeverity, message: string, data: any): Promise<void> {
    // Rate limiting
    const alertKey = `${severity}-${message}`;
    const lastSent = this.alertRateLimiter.get(alertKey) || 0;
    const now = Date.now();

    // Don't send same alert more than once per hour
    if (now - lastSent < 3600000) {
      return;
    }

    this.alertRateLimiter.set(alertKey, now);

    const alert = {
      timestamp: new Date().toISOString(),
      severity,
      message,
      data,
      platform: 'GameFi Platform'
    };

    console.log(`[${severity.toUpperCase()}] ${message}`, data);

    // Send to configured alert channels
    for (const channel of this.config.alertChannels) {
      if (channel.severity.includes(severity)) {
        try {
          await this.sendToChannel(channel, alert);
        } catch (error) {
          console.error('Error sending alert to channel:', error);
        }
      }
    }
  }

  /**
   * Send alert to specific channel
   */
  private async sendToChannel(channel: AlertChannel, alert: any): Promise<void> {
    switch (channel.type) {
      case 'webhook':
        await fetch(channel.url, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(alert)
        });
        break;

      case 'slack':
        await fetch(channel.url, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            text: `🚨 ${alert.severity.toUpperCase()}: ${alert.message}`,
            attachments: [{
              color: this.getSeverityColor(alert.severity),
              fields: Object.entries(alert.data).map(([key, value]) => ({
                title: key,
                value: String(value),
                short: true
              }))
            }]
          })
        });
        break;

      case 'telegram':
        const telegramMessage = `🚨 *${alert.severity.toUpperCase()}*: ${alert.message}\n\n${
          Object.entries(alert.data)
            .map(([key, value]) => `*${key}*: ${value}`)
            .join('\n')
        }`;
        
        await fetch(channel.url, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            text: telegramMessage,
            parse_mode: 'Markdown'
          })
        });
        break;

      case 'email':
        // Email sending would require additional email service configuration
        console.log('Email alert would be sent:', alert);
        break;
    }
  }

  /**
   * Get color for alert severity
   */
  private getSeverityColor(severity: AlertSeverity): string {
    switch (severity) {
      case AlertSeverity.INFO: return '#36a64f';
      case AlertSeverity.WARNING: return '#ff9900';
      case AlertSeverity.CRITICAL: return '#ff0000';
      case AlertSeverity.EMERGENCY: return '#8B0000';
      default: return '#808080';
    }
  }

  /**
   * Get current metrics
   */
  getMetrics(): { transactionMetrics: TransactionMetrics; securityMetrics: SecurityMetrics } {
    return {
      transactionMetrics: { ...this.metrics },
      securityMetrics: {
        suspiciousAddresses: new Set(this.securityMetrics.suspiciousAddresses),
        largeTransfers: [...this.securityMetrics.largeTransfers],
        failedTransactions: [...this.securityMetrics.failedTransactions],
        gasAnomalies: [...this.securityMetrics.gasAnomalies]
      }
    };
  }
}

export {
  GameFiMonitoringService,
  type MonitoringConfig,
  type ContractAddresses,
  type AlertChannel,
  type AlertThresholds,
  type CircuitBreakerConfig,
  AlertSeverity
};