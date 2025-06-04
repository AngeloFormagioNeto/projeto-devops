import { render } from '@testing-library/react';
import { Header } from '.';

test('renders GitFind title', () => {
  const { getByText } = render(<Header />);
  expect(getByText(/GitFind/i)).toBeInTheDocument();
});