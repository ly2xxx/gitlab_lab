/**
 * Sample Express.js Application
 * Demonstrates dependency usage for Renovate testing
 */

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const axios = require('axios');
const _ = require('lodash');
const moment = require('moment');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET || 'demo-secret-key';

// Middleware
app.use(helmet());
app.use(cors());
app.use(morgan('combined'));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// In-memory data store (for demo purposes)
const users = [];
const posts = [];

// Utility functions using dependencies
const hashPassword = async (password) => {
  const saltRounds = 10;
  return await bcrypt.hash(password, saltRounds);
};

const comparePassword = async (password, hash) => {
  return await bcrypt.compare(password, hash);
};

const generateToken = (userId) => {
  return jwt.sign({ userId }, JWT_SECRET, { expiresIn: '24h' });
};

const verifyToken = (token) => {
  try {
    return jwt.verify(token, JWT_SECRET);
  } catch (error) {
    return null;
  }
};

// Authentication middleware
const authenticate = (req, res, next) => {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Authentication required' });
  }
  
  const token = authHeader.substring(7);
  const decoded = verifyToken(token);
  
  if (!decoded) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
  
  req.userId = decoded.userId;
  next();
};

// Routes

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'OK',
    timestamp: moment().toISOString(),
    uptime: process.uptime(),
    dependencies: {
      express: require('express/package.json').version,
      lodash: require('lodash/package.json').version,
      moment: require('moment/package.json').version,
      axios: require('axios/package.json').version,
    },
  });
});

// API info endpoint
app.get('/api', (req, res) => {
  res.json({
    name: 'Renovate Test API',
    version: '1.0.0',
    description: 'Sample API for testing Mend Renovate Community Edition',
    endpoints: {
      'GET /health': 'Health check',
      'GET /api': 'API information',
      'POST /auth/register': 'User registration',
      'POST /auth/login': 'User login',
      'GET /posts': 'Get all posts',
      'POST /posts': 'Create new post (authenticated)',
      'GET /posts/:id': 'Get specific post',
      'GET /external/random-quote': 'Get random quote from external API',
    },
    timestamp: moment().format('YYYY-MM-DD HH:mm:ss'),
  });
});

// Authentication routes
app.post('/auth/register', async (req, res) => {
  try {
    const { username, email, password } = req.body;
    
    if (!username || !email || !password) {
      return res.status(400).json({ error: 'Username, email, and password are required' });
    }
    
    // Check if user already exists
    const existingUser = _.find(users, { email });
    if (existingUser) {
      return res.status(409).json({ error: 'User already exists' });
    }
    
    const hashedPassword = await hashPassword(password);
    const userId = users.length + 1;
    
    const newUser = {
      id: userId,
      username,
      email,
      password: hashedPassword,
      createdAt: moment().toISOString(),
    };
    
    users.push(newUser);
    
    const token = generateToken(userId);
    
    res.status(201).json({
      message: 'User registered successfully',
      user: _.omit(newUser, 'password'),
      token,
    });
  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.post('/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    
    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required' });
    }
    
    const user = _.find(users, { email });
    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }
    
    const isValidPassword = await comparePassword(password, user.password);
    if (!isValidPassword) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }
    
    const token = generateToken(user.id);
    
    res.json({
      message: 'Login successful',
      user: _.omit(user, 'password'),
      token,
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Posts routes
app.get('/posts', (req, res) => {
  const page = parseInt(req.query.page) || 1;
  const limit = parseInt(req.query.limit) || 10;
  const offset = (page - 1) * limit;
  
  const paginatedPosts = _(posts)
    .orderBy(['createdAt'], ['desc'])
    .drop(offset)
    .take(limit)
    .value();
  
  res.json({
    posts: paginatedPosts,
    pagination: {
      page,
      limit,
      total: posts.length,
      totalPages: Math.ceil(posts.length / limit),
    },
  });
});

app.post('/posts', authenticate, (req, res) => {
  try {
    const { title, content } = req.body;
    
    if (!title || !content) {
      return res.status(400).json({ error: 'Title and content are required' });
    }
    
    const user = _.find(users, { id: req.userId });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    const postId = posts.length + 1;
    const newPost = {
      id: postId,
      title,
      content,
      author: _.pick(user, ['id', 'username']),
      createdAt: moment().toISOString(),
      updatedAt: moment().toISOString(),
    };
    
    posts.push(newPost);
    
    res.status(201).json({
      message: 'Post created successfully',
      post: newPost,
    });
  } catch (error) {
    console.error('Post creation error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.get('/posts/:id', (req, res) => {
  const postId = parseInt(req.params.id);
  const post = _.find(posts, { id: postId });
  
  if (!post) {
    return res.status(404).json({ error: 'Post not found' });
  }
  
  res.json({ post });
});

// External API integration (demonstrates axios usage)
app.get('/external/random-quote', async (req, res) => {
  try {
    // Using a public API for demo purposes
    const response = await axios.get('https://api.quotable.io/random', {
      timeout: 5000,
    });
    
    res.json({
      quote: response.data,
      fetchedAt: moment().toISOString(),
      source: 'quotable.io',
    });
  } catch (error) {
    console.error('External API error:', error);
    res.status(502).json({
      error: 'Failed to fetch external data',
      message: error.message,
    });
  }
});

// Utility route demonstrating lodash usage
app.get('/utils/data-demo', (req, res) => {
  const sampleData = [
    { name: 'Alice', age: 30, department: 'Engineering' },
    { name: 'Bob', age: 25, department: 'Marketing' },
    { name: 'Charlie', age: 35, department: 'Engineering' },
    { name: 'Diana', age: 28, department: 'Marketing' },
    { name: 'Eve', age: 32, department: 'Engineering' },
  ];
  
  res.json({
    originalData: sampleData,
    operations: {
      groupByDepartment: _.groupBy(sampleData, 'department'),
      sortedByAge: _.orderBy(sampleData, 'age', 'desc'),
      averageAge: _.round(_.meanBy(sampleData, 'age'), 2),
      engineeringCount: _.filter(sampleData, { department: 'Engineering' }).length,
      oldestPerson: _.maxBy(sampleData, 'age'),
      youngestPerson: _.minBy(sampleData, 'age'),
    },
    processedAt: moment().format('YYYY-MM-DD HH:mm:ss'),
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'development' ? err.message : 'Something went wrong',
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Route not found',
    message: `Cannot ${req.method} ${req.originalUrl}`,
    availableEndpoints: [
      'GET /health',
      'GET /api',
      'POST /auth/register',
      'POST /auth/login',
      'GET /posts',
      'POST /posts',
      'GET /posts/:id',
      'GET /external/random-quote',
      'GET /utils/data-demo',
    ],
  });
});

// Start server
if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`🚀 Server running on port ${PORT}`);
    console.log(`📊 Health check: http://localhost:${PORT}/health`);
    console.log(`📖 API info: http://localhost:${PORT}/api`);
    console.log(`🕐 Started at: ${moment().format('YYYY-MM-DD HH:mm:ss')}`);
  });
}

module.exports = app;
