import React from 'react';
import renderer from 'react-test-renderer';
import ItemList from './index';

test('ItemList snapshot matches', () => {
  const tree = renderer
    .create(<ItemList title="Test Repo" description="Test description" />)
    .toJSON();
  expect(tree).toMatchSnapshot();
});