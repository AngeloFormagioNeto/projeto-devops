import React from "react";
import './styles.css';

function ItemList({title, description}) {
  const link = `https://github.com/AngeloFormagio/${title}`;
  return (
    <div className="item-list">
      <strong><a target="blank" href={link}>{title}</a></strong>
      <p>{description}</p>
      <hr />
    </div>
  );
}

export default ItemList;
