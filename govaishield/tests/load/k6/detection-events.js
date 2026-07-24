import http from 'k6/http';
import { check } from 'k6';
export const options = { stages: [{ duration: '30s', target: 200 }, { duration: '1m', target: 1000 }, { duration: '30s', target: 0 }] };
export default function () {
  const r = http.get('http://localhost:8080/api/v2/health');
  check(r, { 'health 200': (res) => res.status === 200 });
}
