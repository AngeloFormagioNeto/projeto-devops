import React from 'react'; // Importe React se usar JSX
import renderer from 'react-test-renderer';
import ItemList from './ItemList';

test('ItemList snapshot', () => {
  const tree = renderer
    .create(<ItemList title="Test Repo" description="Test description" />)
    .toJSON();
  expect(tree).toMatchSnapshot();
});